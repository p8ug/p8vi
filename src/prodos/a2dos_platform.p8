; what differs between the Apple II's two DOSes for src/appleii/platform.p8:
; ProDOS's here (p8vi-prodos), DOS 3.3's in src/appleii/a2dos_platform.p8.
a2dos {
    ; the variables are at $0800-$1fff (-varsaddress $0800, the Makefile's
    ; PCCARGSPRODOS), below the program, which leaves the text all from the
    ; program's end to $bf00.  (the assembler checks only that they end
    ; before $bf00)
    %asm {{
        .cerror prog8_bss_section_start + prog8_bss_section_size > $2000, "the variables pass $2000, where the program starts"
    }}

    const bool PRODOS = true
    ; (features.PREFIX) what ends a path prefix: /VOLUME/DIR/NAME
    const ubyte PATH_SEP = '/'

    ; where the text memory ends: ProDOS's global page (a system program has
    ; the memory up to it)
    sub text_top() -> uword {
        return $bf00
    }

    ; the spare memory: from the end of the variables up to the program
    asmsub spare_start() -> uword @AY {
        %asm {{
            lda  #<(prog8_bss_section_start + prog8_bss_section_size)
            ldy  #>(prog8_bss_section_start + prog8_bss_section_size)
            rts
        }}
    }
    sub spare_top() -> uword {
        return $2000
    }

    ; what diskio.f_open_w makes: TXT files for the text (plain ASCII, CR
    ; line endings), BIN files for the test build's screens
    sub text_files() {
        diskio.file_type = diskio.TXT
    }
    sub binary_files() {
        diskio.file_type = diskio.BIN
    }
}
