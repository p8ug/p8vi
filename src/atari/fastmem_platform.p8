; the text stores' byte scans and copies on the Atari: in 6502
; assembler (src/fastmem.p8), as on the Commodores
%import fastmem

fastmem {
%option merge
    ; the stores use these routines
    const bool FAST = true
}
