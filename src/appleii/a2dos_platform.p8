; what differs between the Apple II's two DOSes for src/appleii/platform.p8:
; DOS 3.3's here (p8vi-appleii), ProDOS's in src/prodos/a2dos_platform.p8.
a2dos {
    const bool PRODOS = false
    ; (features.PREFIX) what ends a path prefix: DOS 3.3 has none
    const ubyte PATH_SEP = ':'

    ; where the text memory ends: DOS's HIMEM (Applesoft's), where its
    ; buffers start
    sub text_top() -> uword {
        return peekw($73)
    }

    ; (no spare memory: the variables are after the program, the text after
    ; them)
    sub spare_start() -> uword {
        return text_top()
    }
    sub spare_top() -> uword {
        return text_top()
    }

    ; what diskio.f_open_w makes: DOS's T files for the text (bit 7 set on
    ; disk, which diskio takes care of), B files for the test build's
    ; screens
    sub text_files() {
        diskio.file_type = diskio.TEXT
    }
    sub binary_files() {
        diskio.file_type = diskio.BINARY
    }
}
