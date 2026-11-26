; the auxiliary 64 KB of an Apple IIe (with an extended 80-column card), IIc
; or IIgs, for the text: copying between it and main RAM with the
; firmware's AUXMOVE ($c311), which copies $0200-$bfff either way: A1 ($3c)
; the first byte, A2 ($3e) the last, A4 ($42) where it goes, the carry set
; for main to aux.  It runs from the $c3 ROM, so the program's own code
; isn't switched away meanwhile.  ProDOS's MACHID ($bf98) says whether
; there is aux memory (bits 4 and 5: 128 KB).
;
; Used by the page store's driver, src/prodosx/pagemem_platform.p8.

auxmem {
    &ubyte MACHID = $bf98

    ; is there 128 KB?
    sub present() -> bool {
        return MACHID & $30 == $30
    }

    ; copy count bytes from aux memory at src to main memory at dest
    sub fetch(uword src, uword dest, uword count) {
        move(src, dest, count, false)
    }

    ; copy count bytes from main memory at src to aux memory at dest
    sub stash(uword src, uword dest, uword count) {
        move(src, dest, count, true)
    }

    sub move(uword src, uword dest, uword count, bool to_aux) {
        if count == 0
            return
        pokew($3c, src)
        pokew($3e, src + count - 1)
        pokew($42, dest)
        auxmove(to_aux)
    }

    asmsub auxmove(bool to_aux @Pc) clobbers(A, X, Y) {
        %asm {{
            jmp  $c311
        }}
    }

    ; ProDOS's /RAM, a RAM disk in the same aux memory: taken out of the
    ; device list and its driver's place given the "no device" vector, as
    ; ProDOS's technical note 8 has it (programs that use the aux memory
    ; do; the next boot puts /RAM back, empty).  /RAM is slot 3, drive 2.
    &uword DEVADR32 = $bf26
    &uword NODEV = $bf10
    &ubyte DEVCNT = $bf31
    const uword DEVLST = $bf32
    sub disconnect_ram() {
        ubyte i
        ubyte j
        if DEVADR32 == NODEV
            return
        i = 0
        while i <= DEVCNT {
            if @(DEVLST + i) & $f0 == $b0 {
                j = i
                while j < DEVCNT {
                    @(DEVLST + j) = @(DEVLST + j + 1)
                    j++
                }
                @(DEVLST + DEVCNT) = 0
                DEVCNT--
                break
            }
            i++
        }
        DEVADR32 = NODEV
    }
}
