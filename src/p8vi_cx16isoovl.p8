; p8vi - a vi for 8-bit computers, written in Prog8.
; the Commander X16's ISO mode version with overlays: src/p8vi_cx16iso.p8 with
; part of its code in banked RAM (p8p8 only: build with p8c, which writes a small
; loader as the .prg and a .non file; both go on the disk).
; src/p8vi_cx16.p8 with the screen,
; keyboard and text in ISO-8859-15 (txt.iso()), so ASCII files are shown as
; they are, { | } ~ _ included.  Every module is compiled with %encoding iso
; from copies made by tools/encode_copy.py (make build/p8vi-cx16iso.prg,
; bugs/encoding_option.md); this file too, so build it with make.

%import editor
%zeropage basicsafe

; The overlays (p8p8's %overlay, docs/OVERLAYS.md there): this code is in RAM bank 1 and
; is in the window at $a000 only while it runs, which leaves main RAM for the rest.
; What is listed must not use an address inside a text page (buffer.read_room,
; buffer.chunk: the page is in that same window), so load_file and translate_text stay
; in main RAM.  The text's banks begin at 2 (xmem.FIRST), after this one.
%overlay 1, view
%overlay 1, main.execute, main.subst_cmd, main.lines_range, main.set_cmd
%overlay 1, main.edit_cmd, main.write_cmd, main.recover_cmd, main.read_address
%overlay 1, main.save_file, main.write_text

; which optional features the build has (code for the ones that are off
; is left out of the program).  make size shows the room left.
features {
    const bool SPLASH = true    ; the start screen (off: main RAM is full)
    const bool ASCII = false    ; (ISO: the text is ASCII/ISO already, nothing to translate)
    const bool CRLF = true      ; CR LF line endings, :set crlf
    const bool SUBST = true     ; :s/old/new/ and line ranges (:%, :1,5, :$)
    const bool REPEAT_SUBST = true   ; & and :s on its own repeat the last :s (off: main RAM is full)
    const bool DOS = true       ; :@ sends a command to the drive (:@s:name deletes a file)
    const bool FINAL_EOL = true ; a line ending at the end of a file ends the last line (no empty line after it)
    const bool SCROLL = true    ; scroll the screen one row when the cursor goes just off it (not draw it all again)
    const bool DIR = true       ; :@$ shows the disk directory
    const bool FONT = false     ; the C64 font build: oscii.fnt shows the ASCII characters (src/c64/font.p8)
    const bool ISO = true       ; (the X16) ISO mode: the text, keys and screen in ISO-8859-15, not PETSCII (p8vi-cx16iso)
    const bool NUMBER = true    ; :set number: line numbers in front of the lines (about 750 bytes)
    const bool LINE_CMDS = true ; :[range]d and :[range]y, with SUBST's ranges (about 180 bytes)
    const bool SWITCH = false   ; (the C128) the 40/80 DISPLAY key switches the screen while p8vi runs
    const bool PREFIX = true    ; :w keeps a drive or path prefix (0:name, //dir/:name) for the safe save (164 bytes)
    const bool CTRL_AT = false    ; @ then a letter is Ctrl + the letter in normal mode (for keyboards without Ctrl)
    const bool MARKS = true     ; ma, 'a, `a: vi's marks a-z (28 buffer marks instead of 2)
    const bool Z_VIEW = true    ; zt zz zb: the cursor row at the top, middle or bottom of the screen (off: main RAM is full)
}

; features.FONT again, for the assembler (charset.p8's tables).  In main:
; Prog8 leaves the features block out, asm and all (bugs/block_asm_dropped.p8)
main {
    %option merge
    %asm {{
FONT = 0
ISO = 1
    }}
}
