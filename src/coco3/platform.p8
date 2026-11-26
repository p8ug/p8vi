%import diskio
%import strings
%import textio
%import charset_platform

;
; p8vi on the Tandy Color Computer 3 (p8p8's coco3ram target: the program
; has memory blocks of its own where BASIC is, and the 32 KB there are the
; text's): a DECB program for LOADM and EXEC.  The screen is the 80 x 24
; text screen (BASIC's WIDTH 80, which p8vi turns on and puts back at the
; end): cells of a character and an attribute, in a memory block that is
; put at $e000 for the moment of a write.  The keys are the ROM's, the
; files Disk BASIC's ("t.txt" is T.TXT).  The other files of the port are
; the Color Computer 2's (src/coco).
;
platform {
    ; the screen: 80 cells of two bytes a row, at txt.WIDE_SCREEN while
    ; txt.screen_on() has it there (interrupts are off meanwhile, and the
    ; text's last 8 KB are not there: put_row() takes the text first)
    const ubyte COLUMNS = 80
    const uword ROW_BYTES = 160
    ; BASIC's flag for capitals only ($ff; 0: small letters, capitals with
    ; SHIFT): p8vi needs small letters, and puts it back at the end
    const uword CAPS = $011a
    ubyte old_caps
    ubyte old_width         ; BASIC's WIDTH before: 0 is 32 columns, 1 is 40, 2 is 80

    ; memory for the text (the gap buffer), set by init()
    pointer textstart
    pointer texttop         ; 1 byte past the last usable byte
    ; (no spare memory elsewhere)
    pointer sparestart
    pointer sparetop

    ; the text has the memory where BASIC was, up to $fdff (the page at
    ; $fe00 stays BASIC's), from sys.upperstart() on: the compiler puts
    ; most of the program's variables at $8000, to leave room for the
    ; program below.  what is left between the program's end and the stack
    ; is spare memory, less STACK_ROOM for the stack to grow down into
    const uword TEXT_TOP = $fe00
    const uword STACK_ROOM = 384

    sub init() {
        old_caps = @(CAPS)
        @(CAPS) = 0
        old_width = txt.wide
        if old_width != 2
            txt.set_width(80)
        textstart = sys.upperstart() as pointer
        texttop = TEXT_TOP as pointer
        sparestart = sys.progend() as pointer
        sparetop = sparestart
        if sys.stack() - STACK_ROOM > sys.progend()
            sparetop = (sys.stack() - STACK_ROOM) as pointer
        main.SCREEN_WIDTH    = txt.width()
        main.SCREEN_HEIGHT   = txt.height()
        main.STATUS_HEIGHT   = 1
        main.MIN_COL         = 0
        main.MAX_COL         = main.SCREEN_WIDTH - 1
        main.MIN_ROW         = 0
        main.MAX_ROW         = main.SCREEN_HEIGHT - main.STATUS_HEIGHT - 1
        main.STATUS_LINE     = main.SCREEN_HEIGHT - 1
        ; (the test build) the keys to play, from KEYS.TXT
        if features.KEYFILE and diskio.f_open(KEY_FILE) {
            main.key_count = diskio.f_read(main.key_buf, len(main.key_buf))
            diskio.f_close()
        }
    }

    ; (features.KEYFILE, the test build) the keys get_key() gives first:
    ; the editor's codes, as tests/vice/edtest.py's suites type them
    str KEY_FILE = "keys.txt"

    ; before the program ends
    sub stop() {
        @(CAPS) = old_caps
        when old_width {
            0 -> txt.set_width(32)
            1 -> txt.set_width(40)
        }
    }

    ; draw a screen row: n characters of text from column col, control
    ; characters as '.', and spaces before col and after the text (as
    ; src/cbmscreen.p8 does on the CBM machines).  The row is made in
    ; row_buf, characters and attributes, and copied to the screen.
    sub put_row(ubyte r, ubyte col, uword text, ubyte n) {
        ubyte shade = txt.attribute & $3f       ; (no blink, no underline)
        ubyte c
        ubyte i
        pointer cell = &row_buf
        for i in 0 to COLUMNS - 1 {
            c = ' '
            if i >= col and n != 0 {
                c = @(text)
                text++
                n--
                if c == $de
                    c = '~'         ; (the empty rows' marker, PETSCII pi)
                else if c < ' ' or c >= $80
                    c = '.'
            }
            @(cell) = c
            @(cell + 1) = shade
            cell += 2
        }
        txt.screen_on()
        sys.memcopy(&row_buf, txt.WIDE_SCREEN + (r as uword) * ROW_BYTES, ROW_BYTES)
        txt.screen_off()
    }
    ubyte[ROW_BYTES] row_buf

    ; move screen rows first to last count rows up (up: row first+count to
    ; first ... last to last-count) or down (first to first+count ...
    ; last-count to last); the rows moved into aren't changed
    sub scroll_rows(ubyte first, ubyte last, ubyte count, bool up) {
        ubyte r
        txt.screen_on()
        if up {
            for r in first to last - count
                sys.memcopy(txt.WIDE_SCREEN + ((r + count) as uword) * ROW_BYTES, txt.WIDE_SCREEN + (r as uword) * ROW_BYTES, ROW_BYTES)
        } else {
            r = last
            while r >= first + count {
                sys.memcopy(txt.WIDE_SCREEN + ((r - count) as uword) * ROW_BYTES, txt.WIDE_SCREEN + (r as uword) * ROW_BYTES, ROW_BYTES)
                r--
            }
        }
        txt.screen_off()
    }

    ; the cursor: the cell at the text cursor underlined and blinking (the
    ; attribute's top two bits; the machine blinks it by itself, as it does
    ; BASIC's cursor); off puts the cell's attribute back
    uword cursor_cell
    ubyte cursor_shade
    bool cursor_shown = false
    sub cursor(bool on) {
        ubyte shade
        if cursor_shown {
            shade = cursor_shade
            txt.screen_on()
            @(cursor_cell) = shade
            txt.screen_off()
            cursor_shown = false
        }
        if on {
            cursor_cell = txt.WIDE_SCREEN + (txt.get_row() as uword) * ROW_BYTES + (txt.get_column() as uword) * 2 + 1
            txt.screen_on()
            shade = @(cursor_cell)
            txt.screen_off()
            cursor_shade = shade
            shade |= $c0
            txt.screen_on()
            @(cursor_cell) = shade
            txt.screen_off()
            cursor_shown = true
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

    ; platform.stop() puts BASIC's capitals flag back
    const bool PLATFORM_STOP = true
    ; the cursor is a cell that the machine underlines and blinks
    ; (platform.cursor), not a character that p8vi puts there and takes away
    const bool DOS_CURSOR = true
    ; a drive spec comes after the file name: name/ext:1 (editor.p8's
    ; save_file puts its temporary file on the same drive)
    ; (CP/M: text files end at the first ^Z)
    const bool CTRL_Z_EOF = false
    ; (CP/M: a ^Z after a saved text)
    const bool CTRL_Z_SAVE = false
    ; a new text's line ending (editor.p8's ENDING_*): CR
    const ubyte NEW_ENDING = 0
    ; (the Atari: ATASCII text files end their lines with $9b, ENDING_ATASCII)
    const ubyte ATASCII_EOL = 0
    const bool DRIVE_SUFFIX = true
    ; (features.PREFIX) what ends a drive or path prefix
    const ubyte PATH_SEP = ':'
    const ubyte PATH_VOLUME = 0     ; (the Amiga's volume:, a second end of a path prefix)
    ; the drive the DOS opened the last file on (0-7, 255 if unknown)
    sub opened_drive() -> ubyte {
        return diskio.last_drive()
    }
    sub dos_cursor(bool on) {
        platform.cursor(on)
    }

    ; special characters

    const ubyte CHAR_CURSOR     = '_'   ; (not used: the cursor is a cell's attribute)

    const ubyte KEY_ESCAPE      = 27    ; (no key gives it: BREAK is the Escape)
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

    ; Extended BASIC's clock: $0112 counts 60ths of a second, here its low
    ; byte (the cursor blinks by it, about twice a second)
    const uword TICKS = $0113

    bool last_timer = false
    sub blink_timer() -> bool {
        bool temp = @(TICKS) & 32 != 0
        if temp != last_timer {
            last_timer = temp
            return true
        }
        return false
    }

    ; a key, 0 for none.  the ROM's codes, with the editor's for the
    ; arrows, BREAK (3) as RUN/STOP does on CBM (an Escape), and the left
    ; arrow (8) as DEL: the backspace, which deletes in insert mode and on
    ; the : line and moves left otherwise (as h).  SHIFT + left arrow (21)
    ; moves left in insert mode too.  The up arrow is the ^ of this
    ; keyboard (94): it moves up, and SHIFT + up arrow (95) gives the ^.
    ; There is no Ctrl: @ and then the letter in normal mode is Ctrl +
    ; the letter (features.CTRL_AT, editor.p8's ctrl_at).
    ; (the key buffer takes memory from the text)
    const uword KEY_BUF_SIZE = 256
    ubyte[if features.KEYFILE KEY_BUF_SIZE else 1] key_buf
    uword key_count
    uword key_pos
    sub get_key() -> ubyte {
        if features.KEYFILE and key_pos < key_count {
            key_pos++
            return key_buf[key_pos - 1]
        }
        ubyte k = txt.getkey()
        when k {
            94 -> return KEY_UP
            95 -> return '^'
            10 -> return KEY_DOWN
            8 -> return KEY_DEL
            9 -> return KEY_RIGHT
            3 -> return KEY_STOP
            21 -> return KEY_LEFT
        }
        return k
    }

    ; a clock in 60ths of a second: Extended BASIC's
    inline sub ticks() -> uword {
        return sys.ticks()
    }

    ; a character as txt.setchr wants it: ASCII
    inline sub screen_code(ubyte char) -> ubyte {
        return char
    }

    ; the rows past the end of the text, as vi shows them
    str EMPTY_ROW = "~"

    ; (not used: DOS_CURSOR)
    inline sub cursor_char(ubyte char) -> ubyte {
        return CHAR_CURSOR
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
    ; files.  Disk BASIC's files have no drive status here: disk_code is set
    ; like CBM DOS's (0 ok, 62 file not found, 255 any other error), and
    ; status_text says it.
    ;

    ubyte disk_code
    str status_text = " " * 40
    bool io_failed

    ; true if the file can be opened for reading
    sub file_exists(str name) -> bool {
        if diskio.f_open(name) {
            diskio.f_close()
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

    ; rename a file (its directory entry gets the new name).  sets
    ; io_failed if it failed (diskio.status_code() is 0 when the last disk
    ; operation worked).
    sub rename_file(str old, str new) {
        diskio.rename(old, new)
        io_failed = diskio.status_code() != 0
    }

    ; (features.DOS, features.DIR, features.PREFIX: CBM DOS only, off here)
    sub dos_cmd(str command) {
    }
    sub dir_cmd(str name, bool insert) {
    }
    sub dos_command(ubyte c, str name, str old) {
    }
    sub scratch(str name) {
    }
}
