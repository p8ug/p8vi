; p8vi - a vi for 8-bit computers, written in Prog8.
; the Apple II version for DOS 3.3 (a IIe, IIc or IIgs; 48 KB is enough): a
; binary file for $0800 built with p8c's appleii target, see
; src/appleii/platform.p8.  DOS 3.3 leaves $0800-$95ff to a program, so
; this build has the VIC-20's smaller set of features: about 5 KB of text.
; The editor itself is in editor.p8, the C64 version is src/p8vi.p8.

%import editor
%zeropage basicsafe

; which optional features the build has (code for the ones that are off
; is left out of the program).
features {
    const bool SPLASH = false   ; the start screen (off: room for the text, 320 bytes)
    const bool ASCII = false    ; (off: the Apple's text is ASCII already)
    const bool CRLF = true      ; CR LF line endings, :set crlf
    const bool SUBST = false    ; :s/old/new/ and line ranges (:%, :1,5, :$) (off: 1.2 KB)
    const bool REPEAT_SUBST = false   ; & and :s on its own repeat the last :s (needs SUBST)
    const bool DOS = false      ; (CBM DOS only) :@ sends a command to the drive
    const bool FINAL_EOL = true ; a line ending at the end of a file ends the last line (no empty line after it)
    const bool SCROLL = false   ; scroll the screen one row when the cursor goes just off it (off: 580 bytes)
    const bool DIR = false      ; (CBM DOS only) :@$ shows the disk directory
    const bool FONT = false     ; the C64 font build: oscii.fnt shows the ASCII characters (src/c64/font.p8)
    const bool ISO = false     ; (the X16) ISO mode: the text, keys and screen in ISO-8859-15, not PETSCII (p8vi-cx16iso)
    const bool NUMBER = false   ; :set number: line numbers in front of the lines (off: 760 bytes)
    const bool LINE_CMDS = false   ; :[range]d and :[range]y, with SUBST's ranges (about 180 bytes) (needs SUBST)
    const bool SWITCH = false   ; (the C128) the 40/80 DISPLAY key switches the screen while p8vi runs
    const bool PREFIX = false   ; (CBM DOS only) :w keeps a drive or path prefix for the safe save
    const bool CTRL_AT = false  ; @ then a letter is Ctrl + the letter in normal mode (off: the Apple has a CONTROL key)
    const bool MARKS = false    ; ma, 'a, `a: vi's marks a-z (28 buffer marks instead of 2) (off: 480 bytes)
    const bool Z_VIEW = true    ; zt zz zb: the cursor row at the top, middle or bottom of the screen
    const bool KEYFILE = false  ; (the test build) the keys come from the file KEYS first
}
