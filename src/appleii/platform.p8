%import diskio
%import strings
%import textio
%import charset_platform
%import a2dos_platform

;
; p8vi on the Apple II with DOS 3.3 (a IIe, IIc or IIgs; a II Plus shows
; small letters as other signs): built with p8c's appleii target, a binary
; file for $0800 that BRUN starts.  The text is in main RAM from the end of
; the program up to DOS's HIMEM.  The screen is the 40 x 24 text screen:
; the rows are written into its memory directly (the characters with bit 7
; set, the cursor in inverse), the : line through the monitor (txt).  The
; keys come from the keyboard (the arrows are Ctrl-H, U, J, K).  The files
; are DOS's T files (txt's diskio.TEXT).  The other platform files are the
; TRS-80's (charset, store: -srcdirs src:src/appleii:src/trs80); fastmem is
; the 6502 one (src/fastmem.p8).
;
platform {
    const ubyte COLUMNS = 40
    const ubyte ROWS = 24

    ; memory for the text (the gap buffer), set by init()
    pointer textstart
    pointer texttop         ; 1 byte past the last usable byte
    ; spare memory, for the key buffers and the like (ProDOS: between the
    ; variables and the program, a2dos; else none, and take_memory takes
    ; them off the top of the text)
    pointer sparestart
    pointer sparetop

    sub init() {
        textstart = sys.progend()
        texttop = a2dos.text_top()
        sparestart = a2dos.spare_start()
        sparetop = a2dos.spare_top()
        main.SCREEN_WIDTH    = COLUMNS
        main.SCREEN_HEIGHT   = ROWS
        main.STATUS_HEIGHT   = 1
        main.MIN_COL         = 0
        main.MAX_COL         = main.SCREEN_WIDTH - 1
        main.MIN_ROW         = 0
        main.MAX_ROW         = main.SCREEN_HEIGHT - main.STATUS_HEIGHT - 1
        main.STATUS_LINE     = main.SCREEN_HEIGHT - 1
        ; the files p8vi writes are text files (a2dos)
        a2dos.text_files()
        ; (the test build) the keys to play, from KEYS
        if features.KEYFILE and diskio.f_open(KEY_FILE) {
            main.key_count = diskio.f_read(main.key_buf, len(main.key_buf))
            diskio.f_close()
        }
    }

    ; (features.KEYFILE, the test build) the keys get_key() gives first:
    ; the editor's codes, as tests/vice/edtest.py's suites type them
    str KEY_FILE = "keys"

    ; before the program ends.  (the test build: two seconds, so that the
    ; disk drive's motor has stopped, which is when bobbin writes the disk
    ; image back, before tests/appleii/a2test.py's trap at sys.exit ends it)
    sub stop() {
        if features.KEYFILE
            sys.wait(120)
    }

    ; draw a screen row: n characters of text from column col, control
    ; characters as '.', and spaces before col and after the text (as
    ; src/cbmscreen.p8 does on the CBM machines).  The characters go into
    ; the screen's memory with bit 7 set (normal text).
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
                    c = '~'         ; (the empty rows' marker, PETSCII pi)
                else if c < ' ' or c >= $7f
                    c = '.'
            }
            row_buf[i] = c | $80
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
    ; (the TRS-80's name:1; DOS 3.3's files are on the drive it used last)
    const bool DRIVE_SUFFIX = false
    ; (features.PREFIX: ProDOS's) what ends a path prefix
    const ubyte PATH_SEP = a2dos.PATH_SEP
    const ubyte PATH_VOLUME = 0
    sub opened_drive() -> ubyte {
        return 255
    }
    sub dos_cursor(bool on) {
    }

    ; (CP/M: text files end at the first ^Z, and a ^Z after a saved text)
    const bool CTRL_Z_EOF = false
    const bool CTRL_Z_SAVE = false
    ; a new text's line ending (editor.p8's ENDING_*): CR, as DOS 3.3's T
    ; files have
    const ubyte NEW_ENDING = 0
    ; (the Atari: ATASCII text files end their lines with $9b, ENDING_ATASCII)
    const ubyte ATASCII_EOL = 0

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

    ; the cursor blinks by the number of times the keyboard was looked at
    ; (the Apple II has no clock)
    const uword BLINK_POLLS = 800
    uword polls
    sub blink_timer() -> bool {
        polls++
        if polls < BLINK_POLLS
            return false
        polls = 0
        return true
    }

    ; a key, 0 for none: ASCII, with the editor's codes for the arrows
    ; (the left arrow is Ctrl-H, the right one Ctrl-U, up Ctrl-K, down
    ; Ctrl-J: so Ctrl-U is the right arrow here), the left arrow and DELETE
    ; as DEL (as the TRS-80's left arrow: it deletes in insert mode and on
    ; the : line, and moves left otherwise), Ctrl-C as RUN/STOP (an Escape)
    const uword KEY_BUF_SIZE = 256
    ubyte[if features.KEYFILE KEY_BUF_SIZE else 1] key_buf
    uword key_count
    uword key_pos
    sub get_key() -> ubyte {
        if features.KEYFILE and key_pos < key_count {
            key_pos++
            if key_buf[key_pos - 1] == $ff {
                ; (the test build) $ff: the screen to SCREENn, for
                ; tests/appleii/a2test.py
                save_screen()
                return 0
            }
            return key_buf[key_pos - 1]
        }
        ubyte k = txt.getkey()
        if k == 0
            idle_polls++
        when k {
            11 -> return KEY_UP
            10 -> return KEY_DOWN
            21 -> return KEY_RIGHT
            8, 127 -> return KEY_DEL
        }
        return k
    }

    ; (the test build) the screen's memory (40 x 24, the rows in order),
    ; into the B files SCREEN1, SCREEN2 and so on
    str screen_name = "screen0"
    sub save_screen() {
        ubyte r
        screen_name[6]++
        a2dos.binary_files()
        if diskio.f_open_w(screen_name) {
            for r in 0 to platform.ROWS - 1
                void diskio.f_write(txt.rowaddress(r), platform.COLUMNS)
            diskio.f_close_w()
        }
        a2dos.text_files()
    }

    ; a clock for the page store's sync (p8vi-prodosx), which waits for
    ; SYNC_DELAY ticks without a key: the Apple has none, so the times
    ; get_key found no key, by 16 (about a 60th of a second each in bobbin)
    uword idle_polls
    sub ticks() -> uword {
        return idle_polls >> 4
    }

    ; a character as txt.setchr wants it: ASCII
    inline sub screen_code(ubyte char) -> ubyte {
        return char
    }

    ; the rows past the end of the text, as vi shows them
    str EMPTY_ROW = "~"

    ; the cursor: the character under it in inverse (txt.setchr's 128-255)
    inline sub cursor_char(ubyte char) -> ubyte {
        return char | $80
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

    ; (features.PREFIX: ProDOS) delete a file, the path prefix and all
    sub scratch(str name) {
        diskio.delete(name)
    }

    ; (features.PREFIX: ProDOS) the safe save's rename, as CBM DOS's "r"
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
