;
; the console for src/cpm/textio.p8 in the Atari ST build: GEMDOS's
; console, a VT-52 terminal (txt.term = txt.VT52), 40 or 80 columns and 25
; rows.  TOS 1.04 and later.
;
; Output is kept in a buffer and sent when the program waits for a key,
; through the BIOS (Bconout to the console, device 2), not GEMDOS: GEMDOS's
; console output looks for a ^S or ^C typed meanwhile, and takes the key
; it finds from the BIOS (a Ctrl-C, the editor's Escape, ends the
; program there).  start() turns the line wrap off (a
; character in the last column stays there) and the cursor on; stop()
; turns the wrap on again.
;
; Keys come from the BIOS (Bconin of the console, device 2), which gives
; the key's scan code with its character: the arrows, Clr/Home and Undo,
; which have no character, are known by their scan codes (and so are
; Shift with the arrows, which TOS gives the keypad's digits): see key().
; Bconin, unlike GEMDOS's Cconin, takes no ^C or ^S of its own.
;
; (the test build, features.KEYFILE) what is written goes to OUT.LOG too,
; for tests/atarist/sttest.py, from start() on (start's own codes not:
; tests/cpm/termplay.py doesn't know them).
;
console {
    ; the largest screen txt keeps (its buffers' size)
    const ubyte MAX_WIDTH = 80
    const ubyte MAX_HEIGHT = 25
    ; the BIOS keeps keys typed while the screen is sent: txt needn't ask
    const bool KEEPS_KEYS = true

    ubyte[512] out_buf
    uword out_len
    bool started            ; (before start and after stop: written at once)

    ; (the test build) the log of what is written
    str LOG_FILE = "OUT.LOG"
    word log_handle = -1

    sub start() {
        ; (wrap off, cursor on)
        tos.chrout(27)
        tos.chrout('w')
        tos.chrout(27)
        tos.chrout('e')
        if features.KEYFILE {
            long h = diskio.g_create(LOG_FILE)
            if h >= 0
                log_handle = h as word
        }
        started = true
    }

    sub stop() {
        flush()
        started = false
        tos.chrout(27)
        tos.chrout('v')
        if features.KEYFILE and log_handle >= 0 {
            diskio.g_close(log_handle)
            log_handle = -1
        }
    }

    sub out(ubyte char) {
        if not started {
            tos.chrout(char)
            return
        }
        out_buf[out_len] = char
        out_len++
        if out_len == len(out_buf)
            flush()
    }

    sub flush() {
        if out_len != 0 {
            bconout_buf(&out_buf, out_len)
            if features.KEYFILE and log_handle >= 0
                void diskio.g_write(log_handle, &out_buf, out_len)
            out_len = 0
        }
    }

    ; a key typed, 0 for none
    sub poll() -> ubyte {
        flush()
        if not bconstat()
            return 0
        return key(bconin())
    }

    ; a key, waiting for it (the output written first); 0 for a key that
    ; means nothing to the editor (a function key: the caller asks again)
    sub wait() -> ubyte {
        flush()
        return key(bconin())
    }

    ; the editor's code for a key from Bconin: its character, or for a key
    ; without one its scan code's:
    ;   the arrows          up, down, left, right (Shift up and down: a
    ;                       page, Ctrl-B and Ctrl-F)
    ;   Clr/Home            Home (0)
    ;   Undo                u
    ; any other key without a character is 0
    const ubyte SCAN_UP = $48
    const ubyte SCAN_DOWN = $50
    const ubyte SCAN_LEFT = $4b
    const ubyte SCAN_RIGHT = $4d
    const ubyte SCAN_HOME = $47
    const ubyte SCAN_UNDO = $61
    sub key(long k) -> ubyte {
        ubyte scan = lsb(msw(k))
        bool shift = kbshift() & 3 != 0
        when scan {
            SCAN_UP -> {
                if shift
                    return main.KEY_CONTROL_B
                return main.KEY_UP
            }
            SCAN_DOWN -> {
                if shift
                    return main.KEY_CONTROL_F
                return main.KEY_DOWN
            }
            SCAN_LEFT -> return main.KEY_LEFT
            SCAN_RIGHT -> return main.KEY_RIGHT
            SCAN_HOME -> return main.KEY_HOME
            SCAN_UNDO -> return 'u'
        }
        return lsb(k)
    }

    ; the BIOS's calls (trap #13): they keep d3-d7 and a3-a7, Prog8 wants
    ; d2 and a2 too
    asmsub bconin() -> long @D0 {
        ; -- a key from the console, waiting for it: its scan code in bits
        ;    16-23, its character in 0-7
        %asm {{
            movem.l d1-d2/a0-a2,-(sp)
            move.w  #2,-(sp)
            move.w  #2,-(sp)
            trap    #13
            addq.l  #4,sp
            movem.l (sp)+,d1-d2/a0-a2
            rts
        }}
    }

    asmsub bconout_buf(pointer buf @A0, uword count @D0) {
        ; -- count bytes (at least 1) to the console, one Bconout each
        %asm {{
            movem.l d0-d4/a0-a3,-(sp)
            move.l  a0,a3
            move.w  d0,d3
            subq.w  #1,d3
.next:
            moveq   #0,d4
            move.b  (a3)+,d4
            move.w  d4,-(sp)
            move.w  #2,-(sp)
            move.w  #3,-(sp)
            trap    #13
            addq.l  #6,sp
            dbra    d3,.next
            movem.l (sp)+,d0-d4/a0-a3
            rts
        }}
    }

    asmsub bconstat() -> bool @D0 {
        ; -- is a key waiting?
        %asm {{
            movem.l d1-d2/a0-a2,-(sp)
            move.w  #2,-(sp)
            move.w  #1,-(sp)
            trap    #13
            addq.l  #4,sp
            movem.l (sp)+,d1-d2/a0-a2
            and.l   #1,d0
            rts
        }}
    }

    asmsub kbshift() -> ubyte @D0 {
        ; -- the shift keys' state (Kbshift(-1)): bit 0 right Shift, 1 left
        ;    Shift, 2 Control, 3 Alternate
        %asm {{
            movem.l d1-d2/a0-a2,-(sp)
            move.w  #-1,-(sp)
            move.w  #11,-(sp)
            trap    #13
            addq.l  #4,sp
            movem.l (sp)+,d1-d2/a0-a2
            and.l   #$ff,d0
            rts
        }}
    }
}
