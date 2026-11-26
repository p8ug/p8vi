%import diskio
%import strings
%import textio
%import charset_platform

;
; p8vi under MS-DOS (2.0 and later, on an 8086 or 8088 and up): built with
; p8c's dosexe target, an .exe program whose code has a 64 KB segment of
; its own and whose variables, stack and text share another.  The screen
; is the PC's text screen (80 x 25): the rows are written into the video
; RAM directly (colour at $b800, the MDA's at $b000), the cursor and the
; : line go through the BIOS (txt).  The keys come from the BIOS, the
; files through DOS ("c:\dir\name.txt").  The other platform files are
; the TRS-80's (charset, fastmem, store: -srcdirs src:src/dos:src/trs80).
;
;   P8VI [file]
;
platform {
    const ubyte COLUMNS = 80

    ; memory for the text (the gap buffer), set by init()
    pointer textstart
    pointer texttop         ; 1 byte past the last usable byte
    ; spare memory, for the key buffers and the like (none here: the text
    ; has it all, and take_memory takes them off its top)
    pointer sparestart
    pointer sparetop

    ; the data segment: the variables from its start, the stack from its
    ; end down; the text gets what is between, less STACK_ROOM
    const uword STACK_ROOM = 1024

    ; the video RAM's segment: $b000 on a monochrome adapter (the MDA's,
    ; the Hercules card's), which is the BIOS's mode 7 or the equipment
    ; word's (int $11) bits 4-5 both set: DOSBox-X's MDA and Hercules
    ; machines say mode 3, the equipment word has it right
    uword @shared video_seg = $b800

    sub init() {
        options()
        if video_mode() == 7 or equipment() & $30 == $30
            video_seg = $b000
        textstart = sys.progend()
        texttop = sys.stack() - STACK_ROOM
        sparestart = texttop
        sparetop = texttop
        main.SCREEN_WIDTH    = COLUMNS
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

    asmsub video_mode() -> ubyte @AL {
        %asm {{
        mov  ah, 0x0f
        int  0x10
        ret
        }}
    }
    asmsub equipment() -> ubyte @AL {
        %asm {{
        int  0x11
        ret
        }}
    }

    ; the command line: a file to edit, typed as :e name and Enter.  More,
    ; or a name too long, ends the program with a usage line, before
    ; anything is drawn.
    sub options() {
        pointer arg
        if sys.argc() > 2
            usage()
        if sys.argc() == 2 {
            arg = sys.argv(1)
            if arg[0] == '/' or arg[0] == '-' or strings.length(arg) >= len(start_keys) - 5
                usage()
            void strings.copy(":e ", start_keys)
            void strings.copy(arg, &start_keys + 3)
            start_keys[strings.length(start_keys)] = 13
        }
    }

    ; the file named on the command line, typed as :e name and Enter
    ubyte[44] start_keys
    ubyte start_pos

    sub usage() {
        txt.print("usage: p8vi [file]\n")
        sys.exit(1)
    }

    ; (features.KEYFILE, the test build) the keys get_key() gives first:
    ; the editor's codes, as tests/vice/edtest.py's suites type them
    str KEY_FILE = "keys.txt"

    ; before the program ends
    sub stop() {
    }

    ; draw a screen row: n characters of text from column col, control
    ; characters as '.', and spaces before col and after the text (as
    ; src/cbmscreen.p8 does on the CBM machines).  The characters go into
    ; the video RAM, the colours stay.
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
                else if c < ' '
                    c = '.'
            }
            row_buf[i] = c
        }
        video_row(r)
    }
    ubyte[COLUMNS] row_buf

    ; row_buf into screen row r: every other byte of the video RAM (the
    ; ones between are the colours)
    asmsub video_row(ubyte r @AL) {
        %asm {{
        mov  bl, 160
        mul  bl
        mov  di, ax
        mov  si, _platform__row_buf
        mov  cx, 80
        push  es
        mov  es, [_platform__video_seg]
platform_video_row_next:
        movsb
        inc  di
        loop  platform_video_row_next
        pop  es
        ret
        }}
    }

    ; move screen rows first to last count rows up (up: row first+count to
    ; first ... last to last-count) or down (first to first+count ...
    ; last-count to last); the rows moved into aren't changed
    sub scroll_rows(ubyte first, ubyte last, ubyte count, bool up) {
        ubyte rows = last - first - count + 1
        if up
            move_rows(first + count, first, rows)
        else
            move_rows(first, first + count, rows)
    }

    ; rows rows of the video RAM, characters and colours, from row src to
    ; row dest (from the last one back when dest is below src)
    asmsub move_rows(ubyte src @AL, ubyte dest @BL, ubyte rows @CL) {
        %asm {{
        mov  dl, 160
        mul  dl
        mov  si, ax
        mov  al, bl
        mul  dl
        mov  di, ax
        mov  al, cl
        mov  dl, 80
        mul  dl
        mov  cx, ax
        mov  ax, [_platform__video_seg]
        push  ds
        push  es
        mov  ds, ax
        mov  es, ax
        cmp  di, si
        jb  platform_move_rows_up
        mov  ax, cx
        dec  ax
        shl  ax, 1
        add  si, ax
        add  di, ax
        std
        rep movsw
        cld
        jmp  platform_move_rows_end
platform_move_rows_up:
        rep movsw
platform_move_rows_end:
        pop  es
        pop  ds
        ret
        }}
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
    ; the BIOS's cursor, put where the editor's is (editor.p8's
    ; cursor_on): nothing is drawn for it
    const bool DOS_CURSOR = true
    ; (the TRS-80's name:1; DOS's drive comes first, B:NAME, as a
    ; features.PREFIX prefix)
    const bool DRIVE_SUFFIX = false
    ; (features.PREFIX) what ends a path prefix: c:\dir\name, or b:name
    const ubyte PATH_SEP = '\\'
    const ubyte PATH_VOLUME = ':'
    sub opened_drive() -> ubyte {
        return 255
    }
    ; DOS_CURSOR: the BIOS's cursor is where txt.plot put it, or follows
    ; what is written (the : line)
    sub dos_cursor(bool on) {
    }

    ; DOS text files may end at a ^Z
    const bool CTRL_Z_EOF = true
    ; (CP/M: a ^Z after a saved text; DOS doesn't need one)
    const bool CTRL_Z_SAVE = false
    ; a new text's line ending: CR LF, as DOS's text files have
    const ubyte NEW_ENDING = ENDING_CRLF
    ; (the Atari: ATASCII text files end their lines with $9b, ENDING_ATASCII)
    const ubyte ATASCII_EOL = 0

    ; special characters

    const ubyte CHAR_CURSOR     = '_'   ; (not drawn: DOS_CURSOR, the BIOS's)

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

    ; (DOS_CURSOR: the BIOS shows the cursor; nothing blinks)
    sub blink_timer() -> bool {
        return false
    }

    ; a key, 0 for none: the BIOS's, with the editor's codes for the
    ; arrows (128 plus the scan code from txt.getkey), Backspace and Delete
    ; as DEL, Ctrl-C as RUN/STOP (an Escape)
    const uword KEY_BUF_SIZE = 256
    ubyte[if features.KEYFILE KEY_BUF_SIZE else 1] key_buf
    uword key_count
    uword key_pos
    sub get_key() -> ubyte {
        if platform.start_keys[platform.start_pos] != 0 {
            platform.start_pos++
            return platform.start_keys[platform.start_pos - 1]
        }
        if features.KEYFILE and key_pos < key_count {
            key_pos++
            if key_buf[key_pos - 1] == $ff {
                ; (the test build) $ff: the screen to SCREENn.BIN, for
                ; tests/dos/dostest.py
                save_screen()
                return 0
            }
            return key_buf[key_pos - 1]
        }
        ubyte k = txt.getkey()
        when k {
            txt.KEY_UP -> return KEY_UP
            txt.KEY_DOWN -> return KEY_DOWN
            txt.KEY_LEFT -> return KEY_LEFT
            txt.KEY_RIGHT -> return KEY_RIGHT
            txt.KEY_HOME -> return KEY_HOME
            8, 127, txt.KEY_DELETE -> return KEY_DEL
        }
        if k >= 128
            return 0        ; (the other keys without a character)
        return k
    }

    ; (the test build) the characters of the screen (80 x 25), into
    ; SCREEN1.BIN, SCREEN2.BIN and so on
    ubyte[if features.KEYFILE 2000 else 1] screen_buf
    str screen_name = "screen0.bin"
    sub save_screen() {
        get_screen()
        screen_name[6]++
        if diskio.f_open_w(screen_name) {
            void diskio.f_write(&screen_buf, len(screen_buf))
            diskio.f_close_w()
        }
    }
    asmsub get_screen() {
        %asm {{
        mov  di, _main__screen_buf
        mov  cx, 2000
        mov  ax, [_platform__video_seg]
        push  ds
        mov  ds, ax
        xor  si, si
main_get_screen_next:
        lodsw
        stosb
        loop  main_get_screen_next
        pop  ds
        ret
        }}
    }

    ; a clock in 60ths of a second (the BIOS's)
    inline sub ticks() -> uword {
        return sys.ticks()
    }

    ; a character as txt.setchr wants it: code page 437, ASCII's first half
    inline sub screen_code(ubyte char) -> ubyte {
        return char
    }

    ; the rows past the end of the text, as vi shows them
    str EMPTY_ROW = "~"

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
    ; files.  DOS's errors aren't passed on: disk_code is set like CBM
    ; DOS's (0 ok, 62 file not found, 255 any other error), and status_text
    ; says it.
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

    ; rename a file: DOS's (in its drive; it fails when new exists).  sets
    ; io_failed if it failed.
    sub rename_file(str old, str new) {
        diskio.rename(old, new)
        io_failed = diskio.status_code() != 0
    }

    ; (features.PREFIX) delete a file, the path prefix and all
    sub scratch(str name) {
        diskio.delete(name)
    }

    ; (features.PREFIX) the safe save's rename, as CBM DOS's "r" command:
    ; old (p8vi.tmp) gets name's path prefix, so that it is in the same
    ; directory.  sets io_failed if it failed.
    ubyte[80] old_name
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
