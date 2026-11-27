%import diskio
%import strings
%import textio
%import charset_platform
%import strings_platform

;
; p8vi on the classic Macintosh (macplus target: a 68000 Macintosh Plus or
; later, System 4.1 or later), an application whose text is in the
; library's window (80 x 25 in Monaco 9, see macos in its syslib.p8).  The
; editor's rows go straight into that window, as the DOS version writes
; the video RAM: put_row() draws a whole row with DrawText, scroll_rows()
; moves rows with ScrollRect, and the window's copy of its characters
; (macos.screen) is kept the same, for the window's redraws.  The status
; line goes through the library's txt.
;
; The keys are the system's events, read here (not with txt.chrin, which
; makes the command keys the menus' and Return a newline): see map_key().
; The menu's Quit (and command-Q) types Escape and :q, so a changed text
; isn't lost.  The text gets the largest free block of the application's
; heap (the Memory Manager's NewPtr), less MEM_KEPT for the system and
; the desk accessories.  Files are the File Manager's, through the
; library's diskio: new ones are TeachText's text files, with CR line
; endings as a Macintosh's text files have.  The editor core is the wide
; one (32-bit positions), its undo records read a byte at a time
; (tools/encode_copy.py --bytewise), as on the Amiga and the ST.  The
; other platform files are the CP/M version's and the TRS-80's.
;
; A text file opened with p8vi in the Finder (selected with it, then
; File, Open) is edited: the Finder's list of files (the AppParmHandle).
;
platform {
    const ubyte COLUMNS = macos.COLUMNS

    ; memory for the text (the gap buffer), set by init()
    pointer textstart
    pointer texttop         ; 1 byte past the last usable byte
    ; spare memory, for the key buffers and the like (none here: they
    ; come off the text's top)
    pointer sparestart
    pointer sparetop

    ; the text's memory (and the editor's small buffers, off its top: see
    ; main.take_memory): the largest free block, less MEM_KEPT, at most
    ; pos.TEXT_MAX; freed in stop()
    const long MEM_KEPT = 32 * 1024
    long text_size

    sub init() {
        ; (the program's end ends it: the library would wait for a key)
        macos.quit_at_end = true
        options()
        text_size = max_mem() - MEM_KEPT
        if text_size > pos.TEXT_MAX
            text_size = pos.TEXT_MAX
        ; (an even size: the 68000's words and longs)
        text_size &= -2
        if text_size >= 16 * 1024
            textstart = new_ptr(text_size) as pointer
        if textstart == 0 {
            txt.print("p8vi: not enough memory (more for p8vi in the Finder's Get Info)")
            macos.quit_at_end = false
            sys.exit(1)
        }
        texttop = textstart + text_size
        sparestart = texttop
        sparetop = texttop
        main.SCREEN_WIDTH    = COLUMNS
        main.SCREEN_HEIGHT   = macos.ROWS
        main.STATUS_HEIGHT   = 1
        main.MIN_COL         = 0
        main.MAX_COL         = main.SCREEN_WIDTH - 1
        main.MIN_ROW         = 0
        main.MAX_ROW         = main.SCREEN_HEIGHT - main.STATUS_HEIGHT - 1
        main.STATUS_LINE     = main.SCREEN_HEIGHT - 1
        ; (the test build) the keys to play, from KEYS.TXT
        if features.KEYFILE and diskio.f_open(KEY_FILE) {
            main.key_count = diskio.f_read(&main.key_buf, len(main.key_buf)) as uword
            diskio.f_close()
        }
    }

    ; (features.KEYFILE, the test build: tests/macplus/mactest.py) the keys
    ; get_key() gives first: the editor's codes, as tests/vice/edtest.py's
    ; suites type them
    str KEY_FILE = "KEYS.TXT"

    ; the file the Finder opened p8vi with, typed as :e name and Return:
    ; the first of the Finder's list (AppParmHandle, $aec: a word for open
    ; or print, the count, then for each its folder's (working directory's)
    ; number, its type, a version byte and a filler, and its name, with its
    ; length first, to an even length).  Its folder becomes the current one.
    sub options() {
        pointer handle = peekl($0aec) as pointer
        if handle == 0
            return
        pointer p = peekl(handle) as pointer
        if p == 0 or peekw(p) != 0 or peekw(p + 2) == 0
            return
        uword volume = peekw(p + 4)
        ubyte length = @(p + 12)
        if length == 0 or length >= len(start_keys) - 5
            return
        void strings.copy(":e ", start_keys)
        sys.memcopy(p + 13, &start_keys + 3, length)
        start_keys[3 + length] = 13
        start_keys[4 + length] = 0
        macos.clear_pb()
        macos.pb[11] = volume
        void macos.file_call(macos.F_HSETVOL)
    }

    ; keys typed for the editor before the keyboard's: the file from the
    ; Finder (see options), the menu's Quit (see quit)
    ubyte[84] start_keys
    ubyte start_pos

    ; before the program ends: the text's memory freed
    sub stop() {
        if textstart != 0 {
            dispose_ptr(textstart)
            textstart = 0
        }
    }

    ; the Memory Manager's calls (OS traps: the result in d0 or a0)
    asmsub max_mem() -> long @D0 {
        ; -- the largest block the heap can give (after compacting it)
        %asm {{
            movem.l d1-d2/a0-a1,-(sp)
            dc.w    $a11d                   ; _MaxMem
            movem.l (sp)+,d1-d2/a0-a1
            rts
        }}
    }

    asmsub new_ptr(long size @D0) -> long @D0 {
        ; -- a block of size bytes, 0 if there's none
        %asm {{
            movem.l d1-d2/a0-a1,-(sp)
            dc.w    $a11e                   ; _NewPtr
            tst.w   d0
            beq     .got
            sub.l   a0,a0
.got:
            move.l  a0,d0
            movem.l (sp)+,d1-d2/a0-a1
            rts
        }}
    }

    asmsub dispose_ptr(long block @A0) {
        %asm {{
            movem.l d0-d2/a0-a1,-(sp)
            dc.w    $a01f                   ; _DisposPtr
            movem.l (sp)+,d0-d2/a0-a1
            rts
        }}
    }

    ; draw a screen row: n characters of text from column col, control
    ; characters as '.', and spaces before col and after the text (as
    ; src/cbmscreen.p8 does on the CBM machines).  The row goes into the
    ; window's copy (macos.screen), then into the window, all at once.
    sub put_row(ubyte r, ubyte col, pointer text, ubyte n) {
        uword at = (r as uword) * COLUMNS
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
                else if c < ' ' or c == 127
                    c = '.'
            }
            macos.screen[at + i] = c
            macos.attributes[at + i] = 0
        }
        draw_row(r)
    }

    ; row r of macos.screen into the window
    sub draw_row(ubyte r) {
        if macos.reverse
            macos.set_reverse(false)
        macos.move_to(macos.LEFT, macos.TOP + macos.ASCENT + (r as word) * macos.CELL_HEIGHT)
        macos.draw_text(&macos.screen + (r as uword) * COLUMNS, COLUMNS)
    }

    ; move screen rows first to last count rows up (up: row first+count to
    ; first ... last to last-count) or down (first to first+count ...
    ; last-count to last); the rows moved into aren't changed.  The
    ; window's bits move with ScrollRect (what it leaves is white), its copy
    ; of the characters a row at a time.
    sub scroll_rows(ubyte first, ubyte last, ubyte count, bool up) {
        macos.rect[0] = (macos.TOP + (first as word) * macos.CELL_HEIGHT) as uword
        macos.rect[1] = macos.LEFT as uword
        macos.rect[2] = (macos.TOP + (last as word + 1) * macos.CELL_HEIGHT) as uword
        macos.rect[3] = (macos.LEFT + COLUMNS * macos.CELL_WIDTH) as uword
        ubyte r
        if up {
            macos.scroll_rect(count as word)
            for r in first to last - count
                row_copy(r + count, r)
        } else {
            macos.scroll_rect(-(count as word))
            r = last
            while r >= first + count {
                row_copy(r - count, r)
                r--
            }
        }
    }

    sub row_copy(ubyte src, ubyte dest) {
        sys.memcopy(&macos.screen + (src as uword) * COLUMNS, &macos.screen + (dest as uword) * COLUMNS, COLUMNS)
        sys.memcopy(&macos.attributes + (src as uword) * COLUMNS, &macos.attributes + (dest as uword) * COLUMNS, COLUMNS)
    }

    ; (the C128's 40/80 key, the Amiga's window resize; not here)
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

    ;
    ; the keys
    ;

    ; the cursor: the character where the library's txt is (txt.plot, or
    ; after what the : line wrote) in reverse, blinking, while a key is
    ; waited for
    bool cursor_shown
    long blinked
    const long BLINK = 30           ; ticks (60ths of a second)

    sub cursor_flip() {
        macos.cell_rect(macos.column, macos.row, 1)
        macos.invert_rect()
        cursor_shown = not cursor_shown
        blinked = macos.ticks()
    }

    ; a key for the editor, waiting for it
    sub wait_key() -> ubyte {
        ubyte k
        cursor_flip()
        repeat {
            if start_keys[start_pos] != 0 {
                k = start_keys[start_pos]
                start_pos++
                break
            }
            k = next_key()
            if k != 0
                break
            if macos.ticks() - blinked >= BLINK
                cursor_flip()
        }
        if cursor_shown
            cursor_flip()
        return k
    }

    ; the events since the last time: the first key for the editor, 0 for
    ; none.  A click is the menus' or the window's, an update draws the
    ; window again.  (Keys the library's macos.poll took, from txt's
    ; output, come first: their codes are gone, only their characters.)
    sub next_key() -> ubyte {
        ubyte k
        if macos.key_in != macos.key_out {
            k = macos.keys[macos.key_out]
            macos.key_out = (macos.key_out + 1) & 31
            return map_key(k, 0, 0)
        }
        while macos.next_event() {
            when macos.event[0] {
                1 -> click()
                3, 5 -> {
                    k = map_key(lsb(macos.event[2]), msb(macos.event[2]), macos.event[7])
                    if k != 0
                        return k
                }
                6 -> {
                    if mklong2(macos.event[1], macos.event[2]) == macos.window {
                        macos.begin_update()
                        macos.redraw()
                        macos.end_update()
                        ; (the cursor went with the redraw)
                        cursor_shown = false
                    }
                }
                else -> {
                }
            }
        }
        return 0
    }

    ; a click: the menu bar's is the menus' (Quit is quit()), others are
    ; the library's
    sub click() {
        if macos.find_window() == 1 {
            menu(macos.menu_select())
            return
        }
        macos.click()
    }

    sub menu(long choice) {
        uword m = msw(choice)
        if m == 1
            macos.desk_accessory(lsw(choice))
        else if m == 2
            quit()
        macos.menu_done()
    }

    ; the menu's Quit: Escape and :q, as if typed (the editor says it when
    ; the text has changes that aren't saved)
    sub quit() {
        void strings.copy("\x1b:q\r", start_keys)
        start_pos = 0
    }

    ; the key codes (the event's) the editor has its own codes for
    const ubyte CODE_ENTER = $4c        ; the keypad's Enter
    const ubyte CODE_ENTER_128 = $34    ; (the Macintosh 128's and 512's: beside the space bar)
    const ubyte CODE_HOME = $73
    const ubyte CODE_PAGE_UP = $74
    const ubyte CODE_PAGE_DOWN = $79
    const uword COMMAND_KEY = $0100

    ; the editor's code for a key: its character, code (0: not known) and
    ; the event's modifiers.  0 for a key that means nothing to the editor.
    ;   the arrows (28-31)         left, right, up, down
    ;   Delete (8), Del (127)      DEL
    ;   Enter, Clear (27)          Escape (the Macintosh Plus's keyboard has
    ;                              no Escape key, nor Control)
    ;   command and a letter       Control and the letter (command-[ is
    ;                              Escape, command-. RUN/STOP, command-Q Quit)
    ;   Home, Page Up, Page Down   Home, Ctrl-B, Ctrl-F (the extended keyboard)
    ;   option's characters (128-255) nothing
    sub map_key(ubyte c, ubyte code, uword modifiers) -> ubyte {
        if modifiers & COMMAND_KEY != 0 {
            when c {
                '.' -> return main.KEY_STOP
                '[' -> return main.KEY_ESCAPE
                'q', 'Q' -> {
                    quit()
                    return 0
                }
            }
            if (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z')
                return c & 31
            return 0
        }
        when code {
            CODE_ENTER, CODE_ENTER_128 -> return main.KEY_ESCAPE
            CODE_HOME -> return main.KEY_HOME
            CODE_PAGE_UP -> return main.KEY_CONTROL_B
            CODE_PAGE_DOWN -> return main.KEY_CONTROL_F
        }
        when c {
            28 -> return main.KEY_LEFT
            29 -> return main.KEY_RIGHT
            30 -> return main.KEY_UP
            31 -> return main.KEY_DOWN
            8, 127 -> return main.KEY_DEL
        }
        if c >= 128
            return 0
        return c
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

    ; platform.stop() frees the text's memory
    const bool PLATFORM_STOP = true
    ; the cursor is platform.wait_key's, where txt's is (editor.p8's
    ; cursor_on puts it there with txt.plot): nothing is drawn for it
    const bool DOS_CURSOR = true
    ; (the TRS-80's name:1; a Macintosh's path comes first,
    ; Disk:Folder:name, as a features.PREFIX prefix)
    const bool DRIVE_SUFFIX = false
    ; (features.PREFIX) what ends a path prefix: Folder: and Disk:
    const ubyte PATH_SEP = ':'
    const ubyte PATH_VOLUME = ':'
    sub opened_drive() -> ubyte {
        return 255
    }
    ; DOS_CURSOR: the cursor is where txt's is (see platform.wait_key)
    sub dos_cursor(bool on) {
    }

    ; (CP/M's text files end at the first ^Z; not here)
    const bool CTRL_Z_EOF = false
    ; (CP/M: a ^Z after a saved text)
    const bool CTRL_Z_SAVE = false
    ; a new text's line ending: CR, as a Macintosh's
    const ubyte NEW_ENDING = ENDING_CR
    ; (the Atari 8-bit: ATASCII text files end their lines with $9b)
    const ubyte ATASCII_EOL = 0

    ; special characters

    const ubyte CHAR_CURSOR     = '_'   ; (not drawn: DOS_CURSOR)

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

    ; (DOS_CURSOR: platform.wait_key blinks the cursor)
    sub blink_timer() -> bool {
        return false
    }

    ; a key, waiting for it: see platform.map_key.  (the test build) the
    ; keys in KEYS.TXT first, $ff the screen into SCREENn.BIN
    const uword KEY_BUF_SIZE = 1024
    ubyte[if features.KEYFILE KEY_BUF_SIZE else 1] key_buf
    uword key_count
    uword key_pos
    sub get_key() -> ubyte {
        ; (the file from the Finder first: the test build's keys come
        ; after it)
        if platform.start_keys[platform.start_pos] != 0 {
            platform.start_pos++
            return platform.start_keys[platform.start_pos - 1]
        }
        if features.KEYFILE and key_pos < key_count {
            key_pos++
            if key_buf[key_pos - 1] == $ff {
                save_screen()
                return 0
            }
            return key_buf[key_pos - 1]
        }
        return platform.wait_key()
    }

    ; (the test build) the characters of the window (80 x 25), into
    ; screen1.bin, screen2.bin and so on, for tests/macplus/mactest.py
    str screen_name = "screen0.bin"
    sub save_screen() {
        screen_name[6]++
        if diskio.f_open_w(screen_name) {
            void diskio.f_write(&macos.screen, macos.CELLS)
            diskio.f_close_w()
        }
    }

    ; (only the page store's sync uses it, and this build has the gap
    ; buffer)
    sub ticks() -> uword {
        return 0
    }

    ; a character as txt.setchr wants it: ASCII (Mac Roman)
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
    ; files.  The File Manager's errors aren't passed on: disk_code is set
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

    ; rename a file (in one folder: see dos_command; it fails when new
    ; exists).  sets io_failed if it failed.
    sub rename_file(str old, str new) {
        diskio.rename(old, new)
        io_failed = diskio.status_code() != 0
    }

    ; (features.PREFIX) delete a file, the path and all
    sub scratch(str name) {
        diskio.delete(name)
    }

    ; (features.PREFIX) the safe save's rename, as CBM DOS's "r" command:
    ; old (p8vi.tmp) gets name's path, so the rename stays in name's
    ; folder.  sets io_failed if it failed.
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

; the editor's loops use cx16.r0L as a counter (a zero page register on
; the 6502 targets); the m68k targets have no cx16 registers
cx16 {
    ubyte r0L
}
