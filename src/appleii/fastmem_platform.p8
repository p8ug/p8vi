; the text stores' byte scans and copies on the Apple II: in 6502
; assembler (src/fastmem.p8), as on the Commodores.  (the page store,
; p8vi-prodosx, uses them whatever FAST says)
%import fastmem

fastmem {
%option merge
    ; the stores use these routines
    const bool FAST = true
}
