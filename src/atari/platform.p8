%import diskio
%import strings
%import textio
%import charset_platform

;
; p8vi on the Atari 8-bit computers with 48 KB or more (an 800 with 48 KB,
; the XL and XE machines; without the BASIC cartridge) and a DOS (Atari
; DOS 2.0S or 2.5, MyDOS, SpartaDOS ...): built with p8c's atari target,
; an executable (.xex) for $2000.  The text is in main RAM from the end of
; the program up to the OS's MEMTOP (below the screen); the key buffers go
; below the program, from the OS's MEMLO (above DOS) to $2000.  The
; screen is the OS's 40 x 24 text mode: the rows are written into its
; memory (SAVMSC) directly, as screen codes, the cursor in inverse, the :
; line through the screen editor (txt).  The keys come from the OS's
; keyboard handler: the arrows (CTRL and - = + *), RETURN ($9b), DELETE
; BACK SPACE, ESC; BREAK is an Escape too.  The files go through CIO
; (diskio): "NAME.TXT" is D1:NAME.TXT, "D2:NAME.TXT" and "H:NAME.TXT" as
; they are; text files are ATASCII, a line ends with $9b (ATASCII_EOL).
; The other platform files are the TRS-80's (charset, store: -srcdirs
; src:src/atari:src/trs80); fastmem is the 6502 one (src/fastmem.p8).
;
platform {
    const ubyte COLUMNS = 40
    const ubyte ROWS = 24

    ; memory for the text (the gap buffer), set by init()
    pointer textstart
    pointer texttop         ; 1 byte past the last usable byte
    ; spare memory, for the key buffers and the like: below the program,
    ; from DOS's end (MEMLO) to $2000
    pointer sparestart
    pointer sparetop

    &uword MEMLO = $02e7
    &uword MEMTOP = $02e5
    const uword PROGRAM = $2000

    sub init() {
        textstart = sys.progend()
        texttop = MEMTOP
        sparestart = MEMLO
        sparetop = PROGRAM
        if sparestart > sparetop
            sparestart = sparetop
        ; no OS cursor (p8vi draws its own), the margins at 0 and 39
        atari.CRSINH = 1
        atari.LMARGN = 0
        atari.RMARGN = 39
        main.SCREEN_WIDTH    = COLUMNS
        main.SCREEN_HEIGHT   = ROWS
        main.STATUS_HEIGHT   = 1
        main.MIN_COL         = 0
        main.MAX_COL         = main.SCREEN_WIDTH - 1
        main.MIN_ROW         = 0
        main.MAX_ROW         = main.SCREEN_HEIGHT - main.STATUS_HEIGHT - 1
        main.STATUS_LINE     = main.SCREEN_HEIGHT - 1
        ; (the test build) the keys to play, from KEYS
        if features.KEYFILE and diskio.f_open(KEY_FILE) {
            main.key_count = diskio.f_read(main.key_buf, len(main.key_buf))
            diskio.f_close()
        }
    }

    ; (features.KEYFILE, the test build) the keys get_key() gives first:
    ; the editor's codes, as tests/vice/edtest.py's suites type them
    str KEY_FILE = "keys"

    ; before the program ends: the OS's cursor back
    sub stop() {
        atari.CRSINH = 0
    }

    ; draw a screen row: n characters of text from column col, control
    ; characters as '.', and spaces before col and after the text (as
    ; src/cbmscreen.p8 does on the CBM machines).  The characters go into
    ; the screen's memory as screen codes (bit 7: inverse).
    sub put_row(ubyte r, ubyte col, uword text, ubyte n) {
        ubyte c
        ubyte i
        for i in 0 to COLUMNS - 1 {
            c = ' '
            if i >= col and n != 0 {
                c = @(text)
                text++
                n--
                if c == $de
                    c = '-'         ; (the empty rows' marker, PETSCII pi: ATASCII has no ~)
                else if c < ' ' or c == $7f or c == $9b
                    c = '.'
            }
            row_buf[i] = txt.screencode(c)
        }
        sys.memcopy(&row_buf, txt.rowaddress(r), COLUMNS)
    }
    ubyte[COLUMNS] row_buf

    ; move screen rows first to last count rows up (up: row first+count to
    ; first ... last to last-count) or down (first to first+count ...
    ; last-count to last); the rows moved into aren't changed
    sub scroll_rows(ubyte first, ubyte last, ubyte count, bool up) {
        ubyte r
        if up {
            for r in first to last - count
                sys.memcopy(txt.rowaddress(r + count), txt.rowaddress(r), COLUMNS)
        } else {
            r = last
            while r >= first + count {
                sys.memcopy(txt.rowaddress(r - count), txt.rowaddress(r), COLUMNS)
                r--
            }
        }
    }

    ; (the C128: the 40/80 DISPLAY key switches the screen; not here)
    const bool SWITCH = false
    sub switch_wanted() -> bool {
        return false
    }
    sub switch_screen() {
    }

    ; (font builds only; there is none here)
    sub font_mode(bool ascii) -> bool {
        return false
    }

    ; (the X16's ISO build: the cursor as swapped colors; not here)
    sub color_cursor(ubyte col, ubyte row) {
    }

    ; open a file for writing with diskio.f_write.  sets main.io_failed if
    ; that fails.
    sub open_write(str name) -> bool {
        main.io_failed = not diskio.f_open_w(name)
        return not main.io_failed
    }
}

main {
%option merge

    ; screen geometry
    ; per platform and reconfigured per screen mode
    ubyte SCREEN_WIDTH    ; for now
    ubyte SCREEN_HEIGHT   ; for now
    ubyte STATUS_HEIGHT   ; status line size
    ubyte MIN_COL         ; text start column
    ubyte MAX_COL         ; max text column
    ubyte MIN_ROW         ; text start row
    ubyte MAX_ROW         ; max text rows
    ubyte STATUS_LINE     ; what row for the status line

    ; (platform.stop() has nothing to do, but the screen is cleared)
    const bool PLATFORM_STOP = true
    ; (the TRS-80 Model 4's DOS cursor: here p8vi draws its own)
    const bool DOS_CURSOR = false
    ; (the TRS-80's name:1; the Atari's device comes first, D2:NAME, as a
    ; features.PREFIX prefix)
    const bool DRIVE_SUFFIX = false
    ; (features.PREFIX) what ends a device prefix: D2:NAME.TXT, H:NAME
    const ubyte PATH_SEP = ':'
    const ubyte PATH_VOLUME = 0
    sub opened_drive() -> ubyte {
        return 255
    }
    sub dos_cursor(bool on) {
    }

    ; (CP/M: text files end at the first ^Z, and a ^Z after a saved text)
    const bool CTRL_Z_EOF = false
    const bool CTRL_Z_SAVE = false
    ; ATASCII text files end their lines with $9b: a new text's line ending
    ; is that (editor.p8's ENDING_ATASCII)
    const ubyte ATASCII_EOL = $9b
    const ubyte NEW_ENDING = ENDING_ATASCII

    ; special characters

    const ubyte CHAR_CURSOR     = '_'   ; (the cursor is the character in inverse: cursor_char)
    const ubyte KEY_ESCAPE      = 27
    const ubyte KEY_CONTROL_L   = 12

    const ubyte KEY_0           = '0'
    const ubyte KEY_1           = '1'
    const ubyte KEY_2           = '2'
    const ubyte KEY_3           = '3'
    const ubyte KEY_4           = '4'
    const ubyte KEY_5           = '5'
    const ubyte KEY_6           = '6'
    const ubyte KEY_7           = '7'
    const ubyte KEY_8           = '8'
    const ubyte KEY_9           = '9'
    const ubyte KEY_A           = 'a'
    const ubyte KEY_B           = 'b'
    const ubyte KEY_C           = 'c'
    const ubyte KEY_D           = 'd'
    const ubyte KEY_E           = 'e'
    const ubyte KEY_F           = 'f'
    const ubyte KEY_G           = 'g'
    const ubyte KEY_H           = 'h'
    const ubyte KEY_I           = 'i'
    const ubyte KEY_J           = 'j'
    const ubyte KEY_K           = 'k'
    const ubyte KEY_L           = 'l'
    const ubyte KEY_M           = 'm'
    const ubyte KEY_N           = 'n'
    const ubyte KEY_O           = 'o'
    const ubyte KEY_P           = 'p'
    const ubyte KEY_Q           = 'q'
    const ubyte KEY_R           = 'r'
    const ubyte KEY_S           = 's'
    const ubyte KEY_T           = 't'
    const ubyte KEY_U           = 'u'
    const ubyte KEY_V           = 'v'
    const ubyte KEY_W           = 'w'
    const ubyte KEY_X           = 'x'
    const ubyte KEY_Y           = 'y'
    const ubyte KEY_Z           = 'z'

    const ubyte KEY_SHIFT_A     = 'A'
    const ubyte KEY_SHIFT_B     = 'B'
    const ubyte KEY_SHIFT_C     = 'C'
    const ubyte KEY_SHIFT_D     = 'D'
    const ubyte KEY_SHIFT_E     = 'E'
    const ubyte KEY_SHIFT_F     = 'F'
    const ubyte KEY_SHIFT_G     = 'G'
    const ubyte KEY_SHIFT_H     = 'H'
    const ubyte KEY_SHIFT_I     = 'I'
    const ubyte KEY_SHIFT_J     = 'J'
    const ubyte KEY_SHIFT_K     = 'K'
    const ubyte KEY_SHIFT_L     = 'L'
    const ubyte KEY_SHIFT_M     = 'M'
    const ubyte KEY_SHIFT_N     = 'N'
    const ubyte KEY_SHIFT_O     = 'O'
    const ubyte KEY_SHIFT_P     = 'P'
    const ubyte KEY_SHIFT_Q     = 'Q'
    const ubyte KEY_SHIFT_R     = 'R'
    const ubyte KEY_SHIFT_S     = 'S'
    const ubyte KEY_SHIFT_T     = 'T'
    const ubyte KEY_SHIFT_U     = 'U'
    const ubyte KEY_SHIFT_V     = 'V'
    const ubyte KEY_SHIFT_W     = 'W'
    const ubyte KEY_SHIFT_X     = 'X'
    const ubyte KEY_SHIFT_Y     = 'Y'
    const ubyte KEY_SHIFT_Z     = 'Z'

    ; the cursor blinks every 20 60ths of a second (the OS's clock)
    const ubyte BLINK_TICKS = 20
    ubyte blink_last
    sub blink_timer() -> bool {
        if @($14) - blink_last < BLINK_TICKS
            return false
        blink_last = @($14)
        return true
    }

    ; a key, 0 for none: ATASCII, with the editor's codes for the arrows
    ; (CTRL and - = + *: $1c-$1f), RETURN ($9b) as RETURN, DELETE BACK SPACE
    ; ($7e) and CTRL DELETE ($fe) as DEL, BREAK as RUN/STOP (an Escape)
    const uword KEY_BUF_SIZE = 256
    ubyte[if features.KEYFILE KEY_BUF_SIZE else 1] key_buf
    uword key_count
    uword key_pos
    sub get_key() -> ubyte {
        if features.KEYFILE and key_pos < key_count {
            key_pos++
            if key_buf[key_pos - 1] == $ff {
                ; (the test build) $ff: the screen to SCREENn, for
                ; tests/atari/atest.py
                save_screen()
                return 0
            }
            return key_buf[key_pos - 1]
        }
        ubyte k
        void, k = cbm.STOP()
        if k == 0
            return KEY_STOP
        k = txt.getkey()
        when k {
            $1c -> return KEY_UP
            $1d -> return KEY_DOWN
            $1e -> return KEY_LEFT
            $1f -> return KEY_RIGHT
            $9b -> return KEY_RETURN
            $7e, $fe -> return KEY_DEL
        }
        return k
    }

    ; (the test build) the screen's memory (40 x 24 screen codes, the rows
    ; in order), into the files SCREEN1, SCREEN2 and so on
    str screen_name = "screen0"
    sub save_screen() {
        ubyte r
        screen_name[6]++
        if diskio.f_open_w(screen_name) {
            for r in 0 to platform.ROWS - 1
                void diskio.f_write(txt.rowaddress(r), platform.COLUMNS)
            diskio.f_close_w()
        }
    }

    ; a clock in 60ths of a second, for the page store's sync: the OS's
    ; (RTCLOK's two low bytes)
    sub ticks() -> uword {
        return mkword(@($13), @($14))
    }

    ; a character as txt.setchr wants it: ATASCII
    inline sub screen_code(ubyte char) -> ubyte {
        return char
    }

    ; the rows past the end of the text, as vi shows them
    ; (ATASCII has no ~)
    str EMPTY_ROW = "-"

    ; the cursor: the character under it in inverse (txt.setchr's 128-255,
    ; and an inverse one in normal video)
    inline sub cursor_char(ubyte char) -> ubyte {
        return char ^ $80
    }

    ; the number of digits conv.str2uword just read at cmdline[cmd_pos]
    ; (the CBM library leaves the count in r15, this one doesn't)
    sub str2uword_digits() -> ubyte {
        ubyte n = 0
        while cmdline[cmd_pos + n] >= '0' and cmdline[cmd_pos + n] <= '9'
            n++
        return n
    }

    ;
    ; files.  DOS's errors aren't passed on: disk_code is set like CBM
    ; DOS's (0 ok, 62 file not found, 255 any other error), and status_text
    ; says it.
    ;

    ubyte disk_code
    str status_text = " " * 40
    bool io_failed

    ; true if the file can be opened for reading
    sub file_exists(str name) -> bool {
        if diskio.exists(name) {
            disk_code = 0
            return true
        }
        disk_code = 62
        void strings.copy("file not found", status_text)
        return false
    }

    ; disk_code and status_text for the last write or rename
    sub read_disk_status() {
        disk_code = 0
        void strings.copy("ok", status_text)
        if io_failed {
            disk_code = 255
            void strings.copy("disk error", status_text)
        }
        io_failed = false
    }

    ; show the status
    sub disk_error() {
        if disk_code != 62 {
            io_failed = true
            read_disk_status()
        }
        status(status_text)
    }

    ; rename a file: DOS's (it fails when new exists).  sets io_failed if
    ; it failed.
    sub rename_file(str old, str new) {
        diskio.rename(old, new)
        io_failed = diskio.status_code() != 0
    }

    ; (features.PREFIX) delete a file, the device prefix and all
    sub scratch(str name) {
        diskio.delete(name)
    }

    ; (features.PREFIX) the safe save's rename, as CBM DOS's "r"
    ; command: old (p8vi.tmp) gets name's path prefix, so that it is in the
    ; same directory.  sets io_failed if it failed.
    ubyte[if features.PREFIX 66 else 1] old_name
    sub dos_command(ubyte c, str name, str old) {
        if c == 'r' {
            ubyte plen = prefix_len(name)
            sys.memcopy(name, &old_name, plen)
            void strings.copy(old, &old_name + plen)
            rename_file(old_name, name)
        }
    }

    ; (features.DOS, features.DIR: CBM DOS only, off here)
    sub dos_cmd(str command) {
    }
    sub dir_cmd(str name, bool insert) {
    }
}
