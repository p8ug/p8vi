; p8vi - a vi for 8-bit computers, written in Prog8.
; the Atari 130XE version: the Atari version (src/p8vi_atari.p8) with the
; text in pages in the 130XE's extra 64 KB (the page store,
; src/atarixe/pagemem_platform.p8): up to 62 KB of text, and :rec after a
; reset.  On a 64 KB machine it says it needs the 130XE.  The page store's
; code leaves no room for every feature: no start screen, one-row
; scrolling, :set number, marks or zt zz zb.  The editor itself is in
; editor.p8, the C64 version is src/p8vi.p8.

%import editor
%zeropage basicsafe

; which optional features the build has (code for the ones that are off
; is left out of the program).
features {
    const bool SPLASH = false   ; the start screen (off: room for the page slot)
    const bool ASCII = false    ; (off: the text is ATASCII as it is)
    const bool CRLF = true      ; CR LF line endings, :set crlf
    const bool SUBST = true     ; :s/old/new/ and line ranges (:%, :1,5, :$)
    const bool REPEAT_SUBST = true    ; & and :s on its own repeat the last :s (needs SUBST)
    const bool DOS = false      ; (CBM DOS only) :@ sends a command to the drive
    const bool FINAL_EOL = true ; a line ending at the end of a file ends the last line (no empty line after it)
    const bool SCROLL = false   ; scroll the screen one row when the cursor goes just off it (not draw it all again) (off: room for the page slot)
    const bool DIR = false      ; (CBM DOS only) :@$ shows the disk directory
    const bool FONT = false     ; the C64 font build: oscii.fnt shows the ASCII characters (src/c64/font.p8)
    const bool ISO = false     ; (the X16) ISO mode: the text, keys and screen in ISO-8859-15, not PETSCII (p8vi-cx16iso)
    const bool NUMBER = false   ; :set number: line numbers in front of the lines (about 750 bytes) (off: room for the page slot)
    const bool LINE_CMDS = true    ; :[range]d and :[range]y, with SUBST's ranges (about 180 bytes)
    const bool SWITCH = false   ; (the C128) the 40/80 DISPLAY key switches the screen while p8vi runs
    const bool PREFIX = true    ; :w keeps the device (D2:NAME.TXT, H:NAME) for the safe save: p8vi.tmp goes there
    const bool CTRL_AT = false   ; @ then a letter is Ctrl + the letter in normal mode (off: the Atari has a CTRL key)
    const bool MARKS = false   ; ma, 'a, `a: vi's marks a-z (28 buffer marks instead of 2) (off: room for the page slot)
    const bool Z_VIEW = false   ; zt zz zb: the cursor row at the top, middle or bottom of the screen (off: room for the page slot)
    const bool KEYFILE = false  ; (the test build) the keys come from the file KEYS first
}
