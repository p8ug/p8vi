; tests/atarist/sttest.py args: start P8VI.TOS with a command line, as the
; desktop does for a .TTP program (Hatari's --auto can't give one).  The
; command line is TAIL.TXT's text (up to 120 characters, its line end
; dropped).  It ends with Pterm0, not Pterm (sys.exit): the test's
; debugger ends Hatari at the Pterm0, after p8vi's own Pterm.
;
;   p8c -target atarist -o build/argsrun.tos tests/atarist/argsrun.p8

%import diskio

main {
    ; the command tail: its length, then the text (GEMDOS's form)
    ubyte[128] tail

    sub start() {
        ubyte n = 0
        if diskio.f_open("TAIL.TXT") {
            n = diskio.f_read(&tail + 1, 120) as ubyte
            diskio.f_close()
        }
        while n != 0 and (tail[n] == 13 or tail[n] == 10)
            n--
        tail[0] = n
        tail[n + 1] = 0
        void pexec("P8VI.TOS", &tail)
        pterm0()
    }

    ; GEMDOS's Pexec, mode 0 (load and go), the parent's environment
    asmsub pexec(str name @A0, pointer cmdtail @A1) -> long @D0 {
        %asm {{
            movem.l d1-d2/a0-a2,-(sp)
            clr.l   -(sp)
            move.l  a1,-(sp)
            move.l  a0,-(sp)
            clr.w   -(sp)
            move.w  #$4b,-(sp)
            trap    #1
            lea     16(sp),sp
            movem.l (sp)+,d1-d2/a0-a2
            rts
        }}
    }

    asmsub pterm0() {
        %asm {{
            clr.w   -(sp)
            trap    #1
            ; !notreached!
        }}
    }
}
