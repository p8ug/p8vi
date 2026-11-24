; p8c (p8p8 0.5.1-dev), target trs80m4: diskio.rename fails (status 255) when the
; file is on drive 0, LS-DOS's system drive; on drive 1 it works, and prog8c-llvm's
; build (-target llvm16 -triple z80-trs80-m4) works on both.  See the .md.

%import diskio
%import textio
main {
    sub start() {
        ; p8vi's save: write p8vi.tmp, then rename it to the file's name
        if diskio.f_open_w("p8vi.tmp") {
            void diskio.f_write("hello\r", 6)
            diskio.f_close_w()
            txt.print("written ")
            txt.print_ub(diskio.status_code())
            diskio.rename("p8vi.tmp", "r.txt")
            txt.print(" renamed ")
            txt.print_ub(diskio.status_code())
        } else
            txt.print("open failed")
        txt.nl()
    }
}
