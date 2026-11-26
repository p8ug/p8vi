; the 130XE's extra 64 KB, for the text: four banks of 16 KB, one at a time
; at $4000-$7fff in place of the main RAM there, as PORTB ($d301) says:
; bits 2-3 the bank, bit 4 0 for the CPU to see it (bit 5, ANTIC's, stays
; 1: the screen is main RAM's).
;
; p8vi's code runs through $4000-$7fff, so the copy loop runs from page 6
; (from COPY_AT, after the virtual registers: put there by init), with one
; end in the window and the other outside it (the page slots and buffers
; are above $8000).  It switches the bank in, copies, and puts PORTB back
; before it returns into the caller.  The OS's interrupts go on meanwhile:
; their code and data are outside the window.
;
; Used by the page store's driver, src/atarixe/pagemem_platform.p8.

xebank {
    &ubyte PORTB = $d301
    const uword WINDOW = $4000
    const uword COPY_AT = $0680
    ubyte base                  ; PORTB as the program found it

    ; the loop to page 6, and PORTB's value
    sub init() {
        base = PORTB
        sys.memcopy(&copy_code, COPY_AT, COPY_SIZE)
    }

    ; is there extra RAM?  bank 0's first bytes, read through the window,
    ; are the program's own code there on a 64 KB XL (PORTB's bank bits do
    ; nothing on it).  (reading only: a test write would land on the code.)
    ; buf: PROBE bytes outside the window.
    const ubyte PROBE = 64
    sub present(uword buf) -> bool {
        ubyte i
        copy(0, WINDOW, buf, PROBE)
        for i in 0 to PROBE - 1
            if @(buf + i) != @(WINDOW + i)
                return true
        return false
    }

    ; copy count bytes from src to dest with bank b (0-3) in the window
    sub copy(ubyte b, uword src, uword dest, uword count) {
        if count == 0
            return
        cx16.r0L = (base & %11100011) | (b << 2)
        %asm {{
            lda  p8v_src
            sta  P8ZP_SCRATCH_W1
            lda  p8v_src+1
            sta  P8ZP_SCRATCH_W1+1
            lda  p8v_dest
            sta  P8ZP_SCRATCH_W2
            lda  p8v_dest+1
            sta  P8ZP_SCRATCH_W2+1
            lda  p8v_count
            sta  P8ZP_SCRATCH_B1        ; the bytes after the whole pages
            lda  p8b_xebank.p8v_base
            sta  P8ZP_SCRATCH_REG       ; PORTB afterwards
            ldx  p8v_count+1            ; whole pages
            lda  cx16.r0L               ; PORTB with the bank in
            jsr  $0680                  ; COPY_AT
        }}
    }

    ; the loop, relocatable (only relative branches), run at COPY_AT.  in:
    ; A PORTB with the bank in, P8ZP_SCRATCH_W1 the source, P8ZP_SCRATCH_W2
    ; the destination, X whole pages, then P8ZP_SCRATCH_B1 more bytes,
    ; P8ZP_SCRATCH_REG PORTB afterwards
    const ubyte COPY_SIZE = 40
    asmsub copy_code() {
        %asm {{
            sta  $d301
            ldy  #0
            cpx  #0
            beq  _rest
_page       lda  (P8ZP_SCRATCH_W1),y
            sta  (P8ZP_SCRATCH_W2),y
            iny
            bne  _page
            inc  P8ZP_SCRATCH_W1+1
            inc  P8ZP_SCRATCH_W2+1
            dex
            bne  _page
_rest       cpy  P8ZP_SCRATCH_B1
            beq  _done
            lda  (P8ZP_SCRATCH_W1),y
            sta  (P8ZP_SCRATCH_W2),y
            iny
            bne  _rest
_done       lda  P8ZP_SCRATCH_REG
            sta  $d301
            rts
        }}
    }
}
