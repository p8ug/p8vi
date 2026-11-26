%import diskio
%import strings
%import textio
%import charset_platform
%import strings_platform

;
; p8vi on the Atari ST (atarist target: a 68000 and TOS 1.04 or later, or
; EmuTOS), a GEMDOS program (P8VI.TTP: the desktop asks for the file to
; edit): the console is a VT-52 terminal, so the screen is
; src/cpm/textio.p8's, kept in memory and sent when it changes, through
; src/atarist/console_platform.p8 (keys from the BIOS).  Files are
; GEMDOS's, through the library's diskio: new ones get CR LF line
; endings, as TOS's own text files have.  The editor core is the wide one
; (32-bit positions, as the Amiga's and the host's), its undo records read
; a byte at a time (tools/encode_copy.py --bytewise: the 68000's longs
; must be at even addresses).  The other platform files are the CP/M
; version's and the TRS-80's.
;
;   p8vi [file]
;
; The screen is the resolution's: 40 x 25 in the low one, 80 x 25 in the
; medium and high ones.  The text gets the largest free block of memory
; (GEMDOS's Malloc), less MEM_KEPT for the desk accessories and GEMDOS.
;
platform {
    const ubyte COLUMNS = txt.DEFAULT_WIDTH

    ; memory for the text (the gap buffer), set by init()
    pointer textstart
    pointer texttop         ; 1 byte past the last usable byte
    ; spare memory, for the key buffers and the like (none here: they
    ; come off the text's top)
    pointer sparestart
    pointer sparetop

    ; the text's memory (and the editor's small buffers, off its top: see
    ; main.take_memory): the largest free block, less MEM_KEPT, at most
    ; pos.TEXT_MAX; freed in stop()
    const long MEM_KEPT = 16 * 1024
    long text_size

    sub init() {
        options()
        txt.term = txt.VT52
        console.start()
        text_size = malloc(-1) - MEM_KEPT
        if text_size > pos.TEXT_MAX
            text_size = pos.TEXT_MAX
        ; (an even size: the 68000's words and longs)
        text_size &= -2
        if text_size >= 16 * 1024
            textstart = malloc(text_size) as pointer
        if textstart == 0 {
            stop()
            txt.out_str("p8vi: not enough memory\r\n")
            sys.exit(1)
        }
        texttop = textstart + text_size
        sparestart = texttop
        sparetop = texttop
        ; (low resolution: 40 columns)
        txt.resize(if tos.rez == 0 40 else 80, 25)
        set_screen()
        ; (the test build) the keys to play, from keys.txt
        if features.KEYFILE and diskio.f_open(KEY_FILE) {
            main.key_count = diskio.f_read(&main.key_buf, len(main.key_buf)) as uword
            diskio.f_close()
        }
    }

    ; (features.KEYFILE, the test build: tests/atarist/sttest.py) the keys
    ; get_key() gives first: the editor's codes, as tests/vice/edtest.py's
    ; suites type them
    str KEY_FILE = "KEYS.TXT"

    ; the editor's screen size from txt's
    sub set_screen() {
        main.SCREEN_WIDTH    = txt.width()
        main.SCREEN_HEIGHT   = txt.height()
        main.STATUS_HEIGHT   = 1
        main.MIN_COL         = 0
        main.MAX_COL         = main.SCREEN_WIDTH - 1
        main.MIN_ROW         = 0
        main.MAX_ROW         = main.SCREEN_HEIGHT - main.STATUS_HEIGHT - 1
        main.STATUS_LINE     = main.SCREEN_HEIGHT - 1
    }

    ; the command line: a file to edit, typed as :e name.  More than one
    ; argument, or an option, ends the program with a usage line, before
    ; anything is drawn.
    sub options() {
        uword n = sys.argc()
        if n < 2
            return
        pointer arg = sys.argv(1)
        if n > 2 or @(arg) == '-' or strings.length(arg) >= len(start_keys) - 5 {
            txt.out_str("usage: p8vi [file]\r\n")
            sys.exit(1)
        }
        void strings.copy(":e ", start_keys)
        void strings.copy(arg, &start_keys + 3)
        start_keys[strings.length(start_keys)] = 13
    }

    ; the file named on the command line, typed as :e name and Return
    ubyte[84] start_keys
    ubyte start_pos

    ; before the program ends: what is left to send, the console as it was
    ; (the line wrap on), the text's memory freed
    sub stop() {
        txt.done()
        console.stop()
        if textstart != 0 {
            mfree(textstart)
            textstart = 0
        }
    }

    ; GEMDOS's Malloc: a block of size bytes (0 if there's no such block),
    ; or with -1 the size of the largest free one
    asmsub malloc(long size @D0) -> long @D0 {
        %asm {{
            movem.l d1-d2/a0-a2,-(sp)
            move.l  d0,-(sp)
            move.w  #$48,-(sp)
            trap    #1
            addq.l  #6,sp
            movem.l (sp)+,d1-d2/a0-a2
            rts
        }}
    }

    ; GEMDOS's Mfree
    asmsub mfree(long block @A0) {
        %asm {{
            movem.l d0-d2/a0-a2,-(sp)
            move.l  a0,-(sp)
            move.w  #$49,-(sp)
            trap    #1
            addq.l  #6,sp
            movem.l (sp)+,d0-d2/a0-a2
            rts
        }}
    }

    ; draw a screen row: n characters of text from column col, control
    ; characters as '.', and spaces before col and after the text (as
    ; src/cbmscreen.p8 does on the CBM machines)
    sub put_row(ubyte r, ubyte col, pointer text, ubyte n) {
        ubyte c
        ubyte i
        for i in 0 to txt.columns - 1 {
            c = ' '
            if i >= col and n != 0 {
                c = @(text)
                text++
                n--
                if c == $de
                    c = '~'         ; (the empty rows' marker, PETSCII pi)
            }
            txt.put(i, r, c)
        }
    }

    ; move screen rows first to last count rows up (up: row first+count to
    ; first ... last to last-count) or down (first to first+count ...
    ; last-count to last); the rows moved into aren't changed.  (only in
    ; txt's copy: flush() sends the rows that changed)
    sub scroll_rows(ubyte first, ubyte last, ubyte count, bool up) {
        ubyte r
        if up {
            for r in first to last - count
                row_copy(r + count, r)
        } else {
            r = last
            while r >= first + count {
                row_copy(r - count, r)
                r--
            }
        }
    }

    sub row_copy(ubyte src, ubyte dest) {
        sys.memcopy(&txt.want + (src as uword) * COLUMNS, &txt.want + (dest as uword) * COLUMNS, COLUMNS)
        txt.dirty[dest] = true
    }

    ; (the C128's 40/80 key, the Amiga's window resize; not here)
    const bool SWITCH = false
    sub switch_wanted() -> bool {
        return false
    }
    sub switch_screen() {
    }

    ; (font builds only; there is none here)
    sub font_mode(bool ascii) -> bool {
        return false
    }

    ; (the X16's ISO build: the cursor as swapped colors; not here)
    sub color_cursor(ubyte col, ubyte row) {
    }

    ; open a file for writing with diskio.f_write.  sets main.io_failed if
    ; that fails.
    sub open_write(str name) -> bool {
        main.io_failed = not diskio.f_open_w(name)
        return not main.io_failed
    }
}

main {
%option merge

    ; screen geometry
    ; per platform and reconfigured per screen mode
    ubyte SCREEN_WIDTH    ; for now
    ubyte SCREEN_HEIGHT   ; for now
    ubyte STATUS_HEIGHT   ; status line size
    ubyte MIN_COL         ; text start column
    ubyte MAX_COL         ; max text column
    ubyte MIN_ROW         ; text start row
    ubyte MAX_ROW         ; max text rows
    ubyte STATUS_LINE     ; what row for the status line

    ; platform.stop() leaves the console as it was
    const bool PLATFORM_STOP = true
    ; the terminal's own cursor, put where the editor's is (editor.p8's
    ; cursor_on): nothing is drawn for it
    const bool DOS_CURSOR = true
    ; (the TRS-80's name:1; a GEMDOS path comes first, C:\dir\name, as a
    ; features.PREFIX prefix)
    const bool DRIVE_SUFFIX = false
    ; (features.PREFIX) what ends a path prefix: dir\, and the drive's C:
    const ubyte PATH_SEP = '\\'
    const ubyte PATH_VOLUME = ':'
    sub opened_drive() -> ubyte {
        return 255
    }
    ; DOS_CURSOR: the cursor goes where the editor just plotted (on), or
    ; follows what is written (off: the : line)
    sub dos_cursor(bool on) {
        if on
            txt.show_cursor(txt.col, txt.row)
        else
            txt.follow_output()
    }

    ; (CP/M's text files end at the first ^Z; not here)
    const bool CTRL_Z_EOF = false
    ; (CP/M: a ^Z after a saved text)
    const bool CTRL_Z_SAVE = false
    ; a new text's line ending: CR LF, as TOS's
    const ubyte NEW_ENDING = ENDING_CRLF
    ; (the Atari 8-bit: ATASCII text files end their lines with $9b)
    const ubyte ATASCII_EOL = 0

    ; special characters

    const ubyte CHAR_CURSOR     = '_'   ; (not drawn: DOS_CURSOR)

    const ubyte KEY_ESCAPE      = 27
    const ubyte KEY_CONTROL_L   = 12

    const ubyte KEY_0           = '0'
    const ubyte KEY_1           = '1'
    const ubyte KEY_2           = '2'
    const ubyte KEY_3           = '3'
    const ubyte KEY_4           = '4'
    const ubyte KEY_5           = '5'
    const ubyte KEY_6           = '6'
    const ubyte KEY_7           = '7'
    const ubyte KEY_8           = '8'
    const ubyte KEY_9           = '9'
    const ubyte KEY_A           = 'a'
    const ubyte KEY_B           = 'b'
    const ubyte KEY_C           = 'c'
    const ubyte KEY_D           = 'd'
    const ubyte KEY_E           = 'e'
    const ubyte KEY_F           = 'f'
    const ubyte KEY_G           = 'g'
    const ubyte KEY_H           = 'h'
    const ubyte KEY_I           = 'i'
    const ubyte KEY_J           = 'j'
    const ubyte KEY_K           = 'k'
    const ubyte KEY_L           = 'l'
    const ubyte KEY_M           = 'm'
    const ubyte KEY_N           = 'n'
    const ubyte KEY_O           = 'o'
    const ubyte KEY_P           = 'p'
    const ubyte KEY_Q           = 'q'
    const ubyte KEY_R           = 'r'
    const ubyte KEY_S           = 's'
    const ubyte KEY_T           = 't'
    const ubyte KEY_U           = 'u'
    const ubyte KEY_V           = 'v'
    const ubyte KEY_W           = 'w'
    const ubyte KEY_X           = 'x'
    const ubyte KEY_Y           = 'y'
    const ubyte KEY_Z           = 'z'

    const ubyte KEY_SHIFT_A     = 'A'
    const ubyte KEY_SHIFT_B     = 'B'
    const ubyte KEY_SHIFT_C     = 'C'
    const ubyte KEY_SHIFT_D     = 'D'
    const ubyte KEY_SHIFT_E     = 'E'
    const ubyte KEY_SHIFT_F     = 'F'
    const ubyte KEY_SHIFT_G     = 'G'
    const ubyte KEY_SHIFT_H     = 'H'
    const ubyte KEY_SHIFT_I     = 'I'
    const ubyte KEY_SHIFT_J     = 'J'
    const ubyte KEY_SHIFT_K     = 'K'
    const ubyte KEY_SHIFT_L     = 'L'
    const ubyte KEY_SHIFT_M     = 'M'
    const ubyte KEY_SHIFT_N     = 'N'
    const ubyte KEY_SHIFT_O     = 'O'
    const ubyte KEY_SHIFT_P     = 'P'
    const ubyte KEY_SHIFT_Q     = 'Q'
    const ubyte KEY_SHIFT_R     = 'R'
    const ubyte KEY_SHIFT_S     = 'S'
    const ubyte KEY_SHIFT_T     = 'T'
    const ubyte KEY_SHIFT_U     = 'U'
    const ubyte KEY_SHIFT_V     = 'V'
    const ubyte KEY_SHIFT_W     = 'W'
    const ubyte KEY_SHIFT_X     = 'X'
    const ubyte KEY_SHIFT_Y     = 'Y'
    const ubyte KEY_SHIFT_Z     = 'Z'

    ; (DOS_CURSOR: the console shows the cursor; nothing blinks)
    sub blink_timer() -> bool {
        return false
    }

    ; a key: ASCII as the console gives it, the keys without a character
    ; as console.key() makes them.  Delete (127) and Backspace (8) delete
    ; (DEL), Ctrl-C is RUN/STOP (an Escape), Ctrl-L draws the screen again.
    ; It waits for the key.
    const uword KEY_BUF_SIZE = 1024
    ubyte[if features.KEYFILE KEY_BUF_SIZE else 1] key_buf
    uword key_count
    uword key_pos
    sub get_key() -> ubyte {
        ; (the file on the command line first: the test build's keys come
        ; after it, tests/atarist/sttest.py args)
        if platform.start_keys[platform.start_pos] != 0 {
            platform.start_pos++
            return platform.start_keys[platform.start_pos - 1]
        }
        if features.KEYFILE and key_pos < key_count {
            ; (the test build) the screen is sent before each key, as
            ; txt.getkey() does; $ff marks the screen for the test with three
            ; NULs (as tests/cpm/cpmtest.py's)
            txt.flush()
            key_pos++
            if key_buf[key_pos - 1] == $ff {
                txt.out(0)
                txt.out(0)
                txt.out(0)
                return 0
            }
            return key_buf[key_pos - 1]
        }
        ubyte k
        do {
            k = txt.getkey()
        } until k != 0
        when k {
            127, 8 -> return KEY_DEL
            3 -> return KEY_STOP
            KEY_CONTROL_L -> txt.repaint()      ; (the editor draws it all again)
        }
        return k
    }

    ; (only the page store's sync uses it, and this build has the gap
    ; buffer)
    sub ticks() -> uword {
        return 0
    }

    ; a character as txt.setchr wants it: ASCII
    inline sub screen_code(ubyte char) -> ubyte {
        return char
    }

    ; the rows past the end of the text, as vi shows them
    str EMPTY_ROW = "~"

    inline sub cursor_char(ubyte char) -> ubyte {
        return CHAR_CURSOR
    }

    ; the number of digits conv.str2uword just read at cmdline[cmd_pos]
    ; (the CBM library leaves the count in r15, this one doesn't)
    sub str2uword_digits() -> ubyte {
        ubyte n = 0
        while cmdline[cmd_pos + n] >= '0' and cmdline[cmd_pos + n] <= '9'
            n++
        return n
    }

    ;
    ; files.  GEMDOS's errors aren't passed on: disk_code is set like CBM
    ; DOS's (0 ok, 62 file not found, 255 any other error), and status_text
    ; says it.
    ;

    ubyte disk_code
    str status_text = " " * 40
    bool io_failed

    ; true if the file can be opened for reading
    sub file_exists(str name) -> bool {
        if diskio.f_open(name) {
            diskio.f_close()
            disk_code = 0
            return true
        }
        disk_code = 62
        void strings.copy("file not found", status_text)
        return false
    }

    ; disk_code and status_text for the last write or rename
    sub read_disk_status() {
        disk_code = 0
        void strings.copy("ok", status_text)
        if io_failed {
            disk_code = 255
            void strings.copy("disk error", status_text)
        }
        io_failed = false
    }

    ; show the status
    sub disk_error() {
        if disk_code != 62 {
            io_failed = true
            read_disk_status()
        }
        status(status_text)
    }

    ; rename a file (in one directory: see dos_command).
    ; sets io_failed if it failed.
    sub rename_file(str old, str new) {
        diskio.rename(old, new)
        io_failed = diskio.status_code() != 0
    }

    ; (features.PREFIX) delete a file, the path and all
    sub scratch(str name) {
        diskio.delete(name)
    }

    ; (features.PREFIX) the safe save's rename, as CBM DOS's "r" command:
    ; old (p8vi.tmp) gets name's path, so the rename stays in name's
    ; directory.  sets io_failed if it failed.
    ubyte[80] old_name
    sub dos_command(ubyte c, str name, str old) {
        if c == 'r' {
            ubyte plen = prefix_len(name)
            sys.memcopy(name, &old_name, plen)
            void strings.copy(old, &old_name + plen)
            rename_file(old_name, name)
        }
    }

    ; (features.DOS, features.DIR: CBM DOS only, off here)
    sub dos_cmd(str command) {
    }
    sub dir_cmd(str name, bool insert) {
    }
}

; the editor's loops use cx16.r0L as a counter (a zero page register on
; the 6502 targets); the m68k targets have no cx16 registers
cx16 {
    ubyte r0L
}
