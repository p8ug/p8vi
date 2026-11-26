; p8c, appleii (DOS 3.3): every f_open_w / f_write / f_close_w leaves about
; 15 sectors marked used in the VTOC, so writing the same small file again
; and again fills the disk (bugs/p8c_appleii_close_w_leaks_sectors.md).
;   p8c -target appleii -o leak.bin bugs/p8c_appleii_close_w_leaks_sectors.p8
%import textio
%import diskio
%zeropage basicsafe
main {
    sub start() {
        ubyte i
        diskio.file_type = diskio.TEXT
        for i in 1 to 20 {
            txt.print_ub(i)
            txt.spc()
            if diskio.f_open_w("probe") {
                void diskio.f_write("x\n", 2)
                diskio.f_close_w()
                txt.print("w ")
            } else
                txt.print(diskio.status())
        }
        txt.print("done\n")
        ; (so that the drive's motor has stopped and bobbin has written the
        ; disk image back)
        sys.wait(120)
    }
}
