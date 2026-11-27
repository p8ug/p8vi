# p8vi: possible future work

Ideas and known problems for p8vi, roughly by kind, not by priority.
`docs/KEYS.md` lists the vi commands that are done and the ones that
aren't.

## vi commands

- **Line ranges for more commands:** `:1,10w name`, `:1,5>`.  `:s`, `:d`
  and `:y` have them (`read_range()`; `:d` and `:y` are
  `features.LINE_CMDS`, about 180 bytes: off on the X16, p8vi-c128x and
  p8vi-c64font for room (the last two: their page slots), and they took line numbering's place on `p8vi-c128reu`).
- **Scrolling the view:** Ctrl-E / Ctrl-Y (scroll one line), and
  `z<Return>` `z.` `z-` (`zt` `zz` `zb` and the first non-blank).  `zt`
  `zz` `zb` (`features.Z_VIEW`, about 145 bytes) are off on the VIC-20,
  X16, p8vi-mega65dma (no room), p8vi-c128x (the main-RAM page slot),
  p8vi-c64font (the REU slots) and the TRS-80 (edtest's big suite no
  longer fit).  They put the cursor's row at the top or
  bottom, where vi puts the first or last row of a long line.
- **`:set number`** (`features.NUMBER`, done): about 740–800 bytes, 870 on the
  TRS-80 Model 4 (Prog8's calls and loops; the logic is small).  Off on the
  VIC-20 (and 22 columns), X16 (both builds) and p8vi-mega65dma (no room),
  and on the PET (it took 800 bytes of its 3.3 KB of text).  Off in the
  builds whose page slots are in main RAM after the program, found by the
  v0.4 test run: p8vi-c128x (no slot left: `:e` hung; `:d`/`:y` alone
  were still too much), p8vi-c64font (its REU slots no longer fit: the
  pages went to main RAM; also 50 bytes short with only `:d`/`:y`) and p8vi-c64reu (without an REU 1 KB of text
  was left, "too big, cut"; it has its own src/p8vi_c64reu.p8 for this),
  as on p8vi-c128reu.  The numbers are 5 digits and a space, so a
  40-column screen has 34 for text.  Still to do:
  - (done) with no slot the page store hung: the C128 page stores now
    stop with "no room for the page slots" (about 68 bytes), and `make
    quick` runs `pages` on each page-store build;
  - `:set relativenumber`: the same count without adding `cur_line`;
  - a width that grows with the line count, as vi's (4 to start);
  - rewriting `draw_row`'s number and `number_rows` in assembler, to
    bring it to the X16.
- **More marks:** forgetting a mark when its line is deleted, as vi does
  (now it stays where the deletion was).  (`''` and ``` `` ``` are done.)
  Marks (`features.MARKS`, about 400 bytes) are off on the VIC-20, X16,
  p8vi-mega65dma, p8vi-c128x (it would lose its main-RAM page slot),
  p8vi-c128reu, p8vi-c64font (its REU slots ran short: the reu-in-use
  check failed) and the TRS-80 (6% of its text; edtest's big suite no
  longer fit the test build).
- **`&` on the X16 and in `p8vi-c128reu`** (`features.REPEAT_SUBST`,
  about 115 bytes and a 40 byte copy of the last `:s`): the X16's main RAM
  is full, and in `p8vi-c128reu` the copy would push the page slot out of
  `$1300-$1bdf` (32 bytes are left).  The C128's sprite area (`$0e00`)
  could hold the copy.  `g&` (`:%s` again) isn't there either.

## Known problems

- **Keys typed ahead during a failed load are lost.**  For example after
  `:r nofile`.  See `bugs/diskio_missing_file.md`, part 2.
- **An extra empty line at the end of a file, on the VIC-20.**  Fixed on
  the C64 and X16 (`features.FINAL_EOL`: the text doesn't keep a file's
  last line ending, writing puts it back), but it costs about 100 bytes
  the VIC-20 doesn't have, so there a file that ends with a line ending
  still shows an empty last line.
- **Saving with a drive or path prefix** (`:w 0:name`, `//dir/:name`):
  fixed with `features.PREFIX` (164 bytes; the scratch and rename commands
  keep the prefix in front, and the temporary file goes to the same place),
  but it is off where there's no room: p8vi-vic20, p8vi-cx16 and
  p8vi-mega65dma (too long by 59-98 bytes) and p8vi-c128reu (it would
  lose a page slot).  There the library's delete and rename put `s:` and
  `r:` before the whole name, which a prefix doesn't survive.  Only `0:` is
  tested (the `prefix` suite); `//dir/:` needs a CMD drive or SD2IEC.
- **The VIC-20 status line** is only 22 columns: 12 for messages and 10 for
  the line,column position.  Check what gets cut short and whether the two
  parts can run into each other.

## Speed and size

- **Scrolling** (done on the C64 and X16, `features.SCROLL`): the screen
  scrolls when the cursor goes up to 4 rows off it, and only the rows
  that come in are drawn; rows are drawn in assembler (`put_row`).  One
  `j` over 2-row lines went from 274 ms to 84 ms on the C64
  (`tests/bench/viewbench.py`).  Left: `layout()` still works out all rows
  after a scroll (about a quarter of the time); shifting the row tables
  instead costs about 200 bytes the X16 doesn't have.  The VIC-20 has no
  room for the scroll code (SCROLL off) but draws rows in assembler.

- **More assembler:** the byte scans and copies are in `src/fastmem.p8`
  (3-4 times faster; `make bench`), screen rows in `put_row` and
  `scroll_rows` (platform).  The Prog8 code around calls is what costs
  bytes.

- **Ctrl-G could show where the text is** (the REU, bank 1, main RAM),
  like Turbo Macro Pro's `(512k)` on its status line: it would show at a
  glance when a build quietly falls back to main RAM (as p8vi-c64font
  did, 11 bytes short of room for the REU slots).  A fixed tag is about
  15-25 bytes, the REU size more; p8vi-c128reu has about 24 bytes before
  it loses a page slot, so it waits for a round of trimming.  The tests
  catch the fallback already (`reu-in-use` in tests/vice/edtest.py).

## Memory

- **Text in extended memory** (the cx16's banked RAM, a C64 REU): files
  up to 64 KB fit, with yank and undo as big, and `:recover` after a crash
  (done, `docs/XMEM-DESIGN.md`).
- **The X16's main RAM is full** (104 bytes left; the key buffers
  are in golden RAM, after the page store's buffers): the page store's
  code is big.  Parts in assembler, or more feature switches
  (`src/p8vi_cx16.p8`), before adding much there.
- **ISO mode on the X16** (`build/p8vi-cx16iso.prg`, `src/p8vi_cx16iso.p8`):
  the text, keys and screen in ISO-8859-15 (`txt.iso()`), so ASCII files
  show as they are, `{ | } ~ _` included.  Every module of the program is
  compiled with `%encoding iso`, from copies `tools/encode_copy.py` makes in
  `build/cx16iso` (`bugs/encoding_option.md`); the library keeps PETSCII.
  `features.ISO`: `features.ASCII` off (nothing to translate), the cursor
  shown by swapping the colors (`platform.color_cursor`), `:@` commands'
  letters before the `:` in capitals (CMDR-DOS wants `S:`, not ISO's `s`),
  PETSCII again at `:q`.  86 bytes free, against the PETSCII build's 104
  (`:d`/`:y` ranges are on in it, off in the PETSCII build).
  Tried in x16emu (ROM R49) on HostFS and on an SD card image:
  - `:e`, edits, `:w`, `:@s:name` and `:@$` all work;
  - CMDR-DOS stores names as typed, so the ISO build writes `new.txt` and
    `Mixed.txt`, where the PETSCII build writes `NEW.TXT` and `ÍIXED.TXT`.

  Still to do:
  - check the real keyboard's codes in ISO mode (the test typed raw bytes
    through `-bas`): the cursor keys, DEL, Esc, Ctrl;
  - new texts still get CR endings, where LF may suit ISO better;
  - PETSCII files show wrong, as there's no `:set ascii` the other way.

  Done: the rows after the text show vi's `~` (platform.init sets
  EMPTY_ROW, 5 bytes); in `release/` since v0.4.
- **32-bit text positions** (done for the host, the Amiga, the Atari ST and the Macintosh):
  `src/postype.p8` holds what depends on the width (`pos.SIZE`, `pos.NONE`,
  `pos.DIGITS`, `pos.print`, `pos.text`, `pos.parse`, `pos.TEXT_MAX`).  `make host`
  compiles the core from copies with `uword` made `long`
  (`tools/encode_copy.py --wide`), with `src/wide/postype.p8` first: 16 MB
  of text.  It needs a compiler whose `sys.memcopy`/`memset` take a `long`
  count on llvm64.  Tried on a 4.5 MB, 120000-line file (edits on both sides
  of line 65535, undo, `:set number` past 99999, `:100000` and
  `:99998,100002s`).  The Amiga's copies are made with `--bytewise` too (the 68000's longs
  at even addresses only; see Amiga below).  Still to do:
  - the m68k `memset`/`memsetw` still take a `uword` count: the Amiga
    build fills in 32 KB pieces (`pos.memset`, from `--bytewise`), until
    the compiler's take a `long`;
  - the 16-bit core is now tested on the CP/M build in tnylpo only (no
    16-bit host build).
- **The start screen** is off on the VIC-20 (its room went to the safe
  save) and on the X16 (`features.SPLASH`).
- **More text on the VIC-20.**  With RAM in block 5 the text is at
  `$a000-$bfff` (8 KB).  The main RAM after the program was the idea for a
  second text area (a gap buffer split across two memory areas), but the
  program now reaches almost to `$8000`.  Room would have to come from
  features switched off, or from the 3 KB expansion at `$0400-$0fff`.
- **Several files open at once** (multiple buffers).
- **The font build** (`p8vi-c64font`, the OSCII font in `oscii.fnt`): a
  fallback when `oscii.fnt` is missing (it
  stops with "can't load oscii.fnt"); whether the plain C64 build (gap
  buffer) should get it too, which costs it the 2 KB above `$c800`;
  switching the font with the file's kind, as on the MEGA65 (the C64
  character ROM can't be seen from the VIC bank the font is in); vi's `{`
  and `}` paragraph motions, now that they can be typed.

## Pages on disk (`p8vi-c64disk`, an experiment)

The page store with its pages in SEQ files, `p8vi.swp...`, on the
text's drive (`src/diskpage`), for fast devices (IDE64, RAMLink, CMD HD,
SD cards).  A 39 KB file, `:e` / `:w`: about 25 s / 22 s on VICE's host
directory drive; 154 s / 122 s on a 1581 with JiffyDOS (254 s to load
without); about 4 minutes to load on a 1541 with JiffyDOS, most of it the
37 page writes (a directory search, the BAM and 5 blocks each).  Moving
and editing then go about as with an REU.

- **Faster loading and saving:** the page transfer is in assembler now
  (7f9c417), but that was a small part.  Sampling the PC while a 39 KB
  file loads: the KERNAL's byte I/O about 30%, `charset.translate`
  (ASCII to PETSCII) about a third, the page writes about 10%,
  `diskio.f_read` about 9%.  A table for the translation (256 bytes per
  direction) and an assembler loop for reading text files (5.9 s to 3.7 s
  for 39 KB in a benchmark) would help every build with room for them.
- **Scratch the swap files on quitting** (now the next start does it).
- **A full disk** (done): the page count is sized from the blocks free
  at start (4 kept), a failed page write is caught (`READST` after the
  close), its splat file scratched and the write tried again.  While no
  page can be written p8vi keeps one clean page slot, refuses changes
  ("swap disk full"; moving and saving still work) and tries again on the
  next change, so deleting files on the drive (`:@s:...`) lets editing go
  on.  Tested on a full 1541: nothing lost or reordered beyond the
  refused changes.  Refused changes are slow on a 1541 (each one tries a
  write, a few seconds with JiffyDOS).
- **Recovery after a crash:** the swap files survive one; it needs the
  recovery headers in a file.
- **Other targets:** the driver only needs the KERNAL's file calls and
  `platform.KERNAL_OPEN_FILES`.  Not the PET 4032: the program alone is
  6.7 KB too big for it.

## Other targets

- **MEGA65** (`p8vi-mega65`, `p8vi-mega65dma`):
  - `p8vi-mega65dma` has 75 bytes left; SPLASH, SUBST and DIR are off.
  - On real hardware: which character set a MEGA65 starts with (p8vi
    puts the C64's back on quitting, which is what xemu starts with), and
    the attic RAM check on a board without it.
  - Recovery after a reset hasn't been tried.
- **PET** (`p8vi-pet32`, a 4032 with BASIC 4):
  - The PET has no Ctrl key: `@` then a letter is Ctrl in normal mode
    (`features.CTRL_AT`, as on the TRS-80; 133 bytes), RVS gives Ctrl-R.
    Ctrl-W in insert mode (delete a word) still can't be typed.
  - The 8032 (80 columns): Prog8's PET screen routines are 40 columns.
  - The 8096 and 8296 have 64 KB more RAM at `$8000-$ffff`: room for
    the page store.
  - A disk error (no drive) stops p8vi with a BASIC error: BASIC 4's
    OPEN and CHKIN don't return when they fail.
- **Plus/4** (`p8vi-plus4`): `src/plus4/rammode.p8` must stay below
  `$8000` (it switches the RAM in); that holds because the toplevel
  imports `platform` first, but nothing checks it when the program grows.
- **C128** (`p8vi-c128`, native mode; the 40 column VIC-II or the 80
  column VDC screen, whichever is active at the start; `make test-c128`).
  Needs prog8c-llvm ab65226d8 or later (bugs/c128_startup_under_basic_rom.p8).
  - Only 11 KB for text (the program starts at `$1c01`).  `p8vi-c128x`
    (`make test-c128x`) has the text in RAM bank 1 instead, up to about
    60 KB (src/c128bank1: pages copied a byte at a time through the MMU's
    preset configurations, by a loop in the shared RAM at $0200), without
    the start screen and `:@$` for room, and 2 page slots.  Moving through
    about 50 KB of text, the copies from bank 1 can't be noticed (tried on
    VICE, 2026-11-06).  `:rec` after a reset works (bank 1 keeps its
    contents; tests/vice/rectest.py --machine c128 [--no-reu], also with
    p8vi-c128reu's REU).  It is also a font build: oscii.fnt (the C64
    font build's) on either screen, src/c128font/font.p8; without the file
    the ROM's font stays.  The font cost one page slot (755 bytes).
  - `p8vi-c128reu` (`make test-c128reu`): the pages in an REU, 192 KB
    for the text, yank and undo (src/c128reu, src/c64/reu.p8), or in bank
    1 without one; the bank 1 build's room savings and also the one row
    scrolling off (`features.SCROLL`), for 2 page slots.
  - p8vi-c128x, and p8vi-c128reu without an REU, use all of bank 1,
    where BASIC 7 keeps its variables and strings.  Safe after the usual
    `LOAD`/`RUN`: they clear BASIC's variables and string space before p8vi
    starts (checked 2026-11-07).  Only a start without `RUN` (`BLOAD` and
    `SYS 7181`) could have variables to keep.  Using only the part BASIC
    leaves free (STREND $33 to FRETOP $35) was left out: `:rec` would
    have to search bank 1 for the headers after a reset, and
    p8vi-c128reu would lose a page slot.
  - Switching 40/80 while running: p8vi-c128 follows the 40/80 DISPLAY
    key (MMU $d505 bit 7, looked at while waiting for keys; SWAPPER, then
    everything drawn again), 185 bytes (`features.SWITCH`), and
    p8vi-c128x, with its font set up on both screens at the start (162
    bytes there, 1322 left).  Not in p8vi-c128reu (1048 bytes free: it
    would lose a page slot).  The status
    message is lost on a switch.  In VICE: `resourceset "C128ColumnKey"
    "0"` (80) or `"1"` (40) in the monitor.
  - The C128's other keys: TAB, HELP, LINE FEED, the function keys.
  - Colors on the VDC (the attribute memory), `txt` colors and scrolling.
- **TRS-80 Model III with LDOS** (`p8vi-trs80.cmd`, `make trs80`; llvm16
  with the z80-trs80-cmd profile, llvm-z80 and z88dk; src/trs80).  Edits,
  saves and reads files (checked by hand in trs80gp, 2026-11-08); about
  9.6 KB for text with LDOS's HIGH$ at $FFFF (6.6 KB before the compiler's
  -Oz default, 2026-11-10).  Keys: shift + up arrow is
  Escape, BREAK too, the left arrow is backspace (DEL), shift + left moves
  left, Ctrl is shift + down arrow + a letter, or @ then a letter in
  normal mode.  p8vi clears the caps lock
  flag ($4019) and moves LDOS's blinking cursor ($4020) out of the way,
  and puts both back on :q.  `make test-trs80` runs edtest's file suites
  (16 of them, not the CBM ones) with a test build that plays its keys from
  KEYS/TXT (features.KEYFILE, `make trs80-test`), through FreHD's IMPORT2
  and EXPORT2 in trs80gp (tests/trs80/trstest.py).  Open:
  - Screen tests.  trs80gp's paste (`-i`) doesn't reach p8vi's keyboard
    polling, and after a key typed on its keyboard matrix (`-ik`) a file
    open hangs (not with the real keyboard); a JCL file (`DO`) can't drive
    it either.  temp/docs/trs80-ldos-notes.md has the details.
  - Saves are slow: about 6.5 s of turbo trs80gp time per :w on top of
    the writing, nearly all the DOS's directory work (about 8 searches:
    deletes, opens, the copy).  The safe save uses diskio.rename(), the
    profile's copy and delete (no DOS call renames), and checks
    diskio.status_code() after it.  Left as it is on purpose: when the
    compiler's rename gets faster, use that.
  - Scrolling (features.SCROLL) copied the wrong memory until 2026-11-09
    (`VIDEO + (r + count) as uword * COLUMNS` is `(VIDEO + r + count) *
    COLUMNS`: the ROM, so nothing moved) and no test looks at the screen.
    The text room was down to a few bytes for edtest's big g3 (STACK_ROOM
    went from 512 to 256 for the fix's 10 bytes); -Oz gave 3.5 KB back.
- **TRS-80 Model 4** (`p8vi-trs80m4.cmd`, `make trs80m4`; the z80-trs80-m4
  profile; src/trs80m4, with src/trs80's other files).  TRSDOS 6 or
  LS-DOS 6.3, 80 x 24.  About 15 KB for text, so marks and zt zz zb
  are in.  z88dk's AMALLOC makes the heap only 75% of the memory below the
  stack: the platform uses the rest as spare memory (the key buffers), and
  FILE_ROOM is 1 KB (the DOS renames: one file open at a time).  The
  profile could do this itself: `-pragma-define:CRT_STACK_SIZE=512` gives
  the heap everything but the stack.  The screen: rows and scrolling go straight to the video RAM at
  $f800 (memory map 2, port $84; TRSDOS 6 leaves it on), with interrupts
  off; the cursor is the DOS's own (DOS_CURSOR: txt.plot and display
  codes 14/15), which it blinks, off while the screen is drawn.  Keys from
  @KBD: up 11, down 10, left 8, right 9, BREAK 128, shift + up 27, CTRL
  + letter 1-26, F1-F3 129-131.  The DOS renames files.  `make
  test-trs80m4` runs the file suites (19, with marks and zview) in trs80gp
  with the LS-DOS 6.3 utility disk (`:lu4`, IMPORT2 and EXPORT2) and a
  test build (`make trs80m4-test`; trstest.py --model 4).  If the DOS's
  cursor ever misbehaves, DOS_CURSOR false gives p8vi's own (a blink
  every 400 keyboard polls looked right in trs80gp).  Open:
  - **p8vi-trs80m4x** (`make trs80m4x`, done): the text in the second
    64 KB, up to about 60 KB (62 pages of 1 KB and two headers for :rec),
    src/trs80m4x.  Port $84 bits 6-4 = 110 / 111 put one of its 32 KB
    halves at $0000-$7fff (MAME's table; trs80gp does it; not yet seen on
    a real Model 4): a copy routine above $8000 does the copying with
    interrupts off, between that window and 2 to 4 slots above $8000 (as
    many as fit: the program is about 43 KB, the page store is big in Z80
    code).  The start screen, marks, zt zz zb and SCROLL are off for room.
    fastmem has Prog8 loops here (the page store needs them; the TRS-80's
    were stubs, the gap buffer has its own).  `make test-trs80m4x` runs the
    file suites with -mem 128, and the page store's (not huge).  `:rec`
    works after a reset in trs80gp (`-ictl reset`; the sync needed a
    clock: `ticks()` is the compiler's `sys.ticks()`, 60ths of a second, since
    2026-11-10): tests/trs80/rectest.py in `make test-trs80m4x`.  Open: a 64 KB Model 4 falls
    back to main RAM with only a page or two (use p8vi-trs80m4 there); an
    NMI while a page is in the window would find no handler.
  - The function keys (F1-F3), `:r $` / `:@$` (the DOS has a directory).
  - Screen tests: trs80gp's `-it` writes the text screen to a file.
- **TRS-80 Model I** (not supported yet; tried in trs80gp on 2026-11-10 with
  the v0.3.1 `p8vi-trs80.cmd`).  The Model III build runs unchanged: under
  LDOS 5.3.1 (`-m1 -ld`) and TRSDOS 2.3 (plain `-m1`) it starts and shows
  the start screen.  All 17 file suites pass under LDOS (with trstest.py
  given a model `'1': (['-m1'], ':lu1', ...)`, as for model 3).  The
  suites play keys from a file, so they miss what's wrong:
  - **Letter case swapped** when typing ("Hello" comes out as "hELLO").
    platform.init writes 0 to `$4019`, the Model III ROM's caps lock flag.
    On a Model I that is something else, so don't write it there.  The
    Model I's keyboard gives capitals unless shifted: swap the case of
    letters from `txt.getkey()`.
  - **No cursor.**  blink_timer reads `$4216` (LDOS's timer on the Model
    III), which doesn't count on a Model I: the cursor is never drawn.
    `sys.ticks()` is 0 on a Model I (compiler docs), so show it without
    blinking, or count passes through the key loop.
  - **Without the lower-case kit** (`-nlc`) lower case shows as symbols
    (bit 6 of the video RAM is missing): "Prog8 VI (p8vi)" is
    `P2/'8 VI (086))`, and the `~` rows are `>`.  Test for the kit at the
    start (write a lower-case letter to the video RAM and read it back), and
    without it show everything in upper case.
  - Telling the models apart: the ROM byte at `$0125` is `I` (73) on a
    Model III (the usual check; not verified here yet).  One `.cmd` can
    serve both.
  - Keys typed with `-ik` faster than hold/gap 15/15 frames get lost or
    garbled on both models (test timing, not p8vi).
  - Better done in the compiler's profile (bugs/trs80_model1_support.md):
    `sys.ticks()`, the model, `txt.getkey()`'s case and the lower-case test.
- **CP/M** (`p8vi-cpm.com`, `make cpm`; llvm16 z80-cpm; src/cpm).  A
  terminal screen kept in memory, sent as changes: `-t ansi` (default),
  `vt52` (tnylpo's full screen), `adm3a`.  Checked in tnylpo (all three
  terminals give the same screen as a Ctrl-L redraw) and on the TRS-80
  Model 4 with Montezuma Micro CP/M 2.2 in trs80gp (`-t adm3a` works;
  17,202 bytes free with its 64K CP/M; `make emu-trs80m4-cpm` boots a
  copy of the system disk with a data disk in drive B made by
  tools/cpm/m4disk.py).  Also tried by hand on the C128's CP/M 3.0 in
  x128 (2026-11-10): `-t adm3a` works on both screens, 20,914 bytes free,
  but slow.  Its 40 column screen is a window on an 80 column console
  (CP/M says 80 columns), so p8vi draws 80 wide there.  Getting files on
  was the hard part: cpmtools has no C128 formats; a CP/M tool (rdcbm)
  read p8vi.com off a 1541 .d64.  Not a practical target.  Open:
  - Tests (`make test-cpm`, tests/cpm): edtest's file suites and its
    screen suites on each terminal (against a Ctrl-L redraw) in tnylpo,
    and a smoke test on Montezuma CP/M in trs80gp (m4test.py, only with
    the disk image: CPM_DISK or build/cpm222_work.dsk).  Each is skipped
    without its emulator.
  - Arrow keys (2026-11-10): txt.escape_key reads ANSI's ESC [ A-D, Home
    (ESC [ H, 1~, 7~), Page Up/Down (5~ 6~: Ctrl-B/F), drops the
    sequences it doesn't know, and with -t vt52 ESC A-D.  `make emu-cpm`
    runs tnylpo -s -w (VT52 arrows; without -w it sends WordStar's ^E ^S
    ^D ^X, which are vi keys).  Checked in tnylpo -s -w through a pty.
    Not ADM-3A's (^K ^J ^H ^L are vi keys too), nor Montezuma's arrows
    (unknown: try them in trs80gp).  On CP/M a sequence's bytes must come
    within 255 console polls; a fast typist's Escape then A on VT52 could
    be taken for up.
  - Montezuma's keyboard: capitals until CAPS is pressed; BREAK is
    Escape.  Keys typed while the floppy is read are lost (no type-ahead);
    txt.flush() asks for keys every 16 characters, so typing during a
    screen update is kept.
  - A Montezuma console driver of its own (its codes beyond ADM-3A:
    clear to end of line would save a lot of spaces), and the C128's CP/M
    (ADM-31: clear to end of line).
  - `-40` draws 40 columns wide (70 bytes; for the C128's 40 column
    window, which CP/M reports as 80; checked in tnylpo, and by the user
    on the C128 in x128: the splash is centred, lines wrap at 40).  Other sizes (`-w`, `-h`, or CP/M 3's SCB, BDOS 49) only if a
    terminal needs them.
  - The C128's RUN/STOP isn't Escape, and won't be: its ESC key is in a
    good spot, and Ctrl-C is Escape too (KEY_STOP).  RUN/STOP sends
    nothing: the BIOS key table (4 codes a key: plain, caps, shift,
    control; at $1290 in bank 0 in the 28 May 87 BIOS, RUN/STOP at $138c)
    has 00 00 00 f0 for it.  CP/M's KEYFIG can give it $1b.
  - The z80-cpm profile doesn't turn on z88dk's heap (the Makefile's link
    options do) and its txt has no getchr and plots 0-based to ANSI (one
    row and column off): worth a note to the compiler side.
- **MS-DOS** (`p8vi-dos.exe`, `make dos`; p8c's dosexe target; src/dos
  with src/trs80's charset, fastmem and store).  An .exe with split code
  and data: the code (about 23 KB) has a segment of its own, so the text
  gets the data segment less the variables and 1 KB of stack, about 55 KB
  (the same build as a .COM, `-target dos`, has about 32 KB).  The rows
  and scrolling go into the video RAM directly ($b800, or $b000 on a
  monochrome adapter), the status line and cursor through the BIOS.
  - Tests (`make test-dos`, tests/dos/dostest.py): edtest's file suites,
    its screen suites against a Ctrl-L redraw and with :set number, in
    DOSBox-X -silent (no window; about 2 s each).  The test build writes
    the video RAM's characters to SCREENn.BIN at a $ff key.
  - DOSBox-X's MDA and Hercules machines report BIOS mode 3, not 7: the
    equipment word (int $11) tells monochrome.  There the BIOS's own
    output (the status line) doesn't show in the dump; real hardware
    has mode 7.  Not tried on real hardware yet.
  - A text ends at its first ^Z (CTRL_Z_EOF), but none is written after
    it (CTRL_Z_SAVE: only CP/M's records need one).
  - `p8vi [file]`: the file is typed as `:e name` at the start (as the
    host version does); anything more prints a usage line.
  - `make size`: p8size on p8c's `.p8map`, with `--memtop 0xfc00`: the
    text goes up to the stack less 1 KB, past the target's memory_end
    ($f000, where the program and its variables must end).
  - Ideas: a 40-column mode, the screen's height from the BIOS (43/50
    rows on EGA/VGA), more of the 640 KB (far text).
- **Apple II** (`p8vi-appleii.bin`, `make appleii`; p8c's appleii target,
  DOS 3.3; src/appleii with src/trs80's charset, fastmem and store).  A
  binary file for $0800 (`-address`), BRUN from DOS.  DOS 3.3 leaves a
  program $0800-$95ff: the full editor (31.6 KB of code and 2.9 KB of
  variables) leaves 1.8 KB, too little for the editor's buffers, so the
  build has the VIC-20's features (plus FINAL_EOL and Z_VIEW): 5.5 KB.
  40 x 24, the rows straight into the screen's memory, the cursor in
  inverse; the files are T files (diskio.TEXT).  The right arrow is
  Ctrl-U (21), so Ctrl-U is lost; the left arrow (8) and DELETE are DEL.
  - Tests (`make test-appleii`, tests/appleii/a2test.py): edtest's file
    and screen suites in bobbin (--simple --turbo), on a copy of A2_DISK
    (the system master, as it is); dos33 puts P8VI,
    KEYS and T.TXT on it and gets the files back.  bobbin quirks: the
    first line typed during the boot can get lost (PRINT 1+1 first); with
    --turbo the boot takes over a minute of emulated time and a save
    about 30 s (--max-runtime 3000); it ends at --trap-success on sys.exit (from the
    .p8map), and writes the disk image back only when the drive's motor
    stops (the test build waits 2 s in platform.stop).  Not `big` (its
    :r makes 6 KB), nor subst, marks.
  - Fixed in p8c (2026-11-26): diskio left the rest of a file's track
    allocated at every write, and after a program that printed the
    return to BASIC lost DOS's stack pointer
    (bugs/p8c_appleii_close_w_leaks_sectors.md).  Checked in bobbin: 8
    writes leave the free sectors less the file's 2; :q! then PRINT and
    CATALOG at the prompt work.
- **ProDOS** (`p8vi-prodos.sys`, `make appleii`; p8c's prodos target, a
  system program for $2000; src/prodos/a2dos_platform.p8 with
  src/appleii's platform: a2dos has what differs, the text top, the file
  types, the path separator).  Every feature, PREFIX with '/': 29.9 KB of
  code at $2000, the variables (3.8 KB, ProDOS's two 1 KB file buffers
  among them) at $0800 (-varsaddress; an assembler check that they end
  below $2000), and 10.8 KB from the code's end to $bf00.
  - Tests (`make test-appleii`, a2test.py --prodos): files, screen and
    number, all pass, seconds each (ProDOS boots fast): a copy of bobbin's
    prodos242.dsk (BASIC.SYSTEM), the files put on and read back with
    AppleCommander's ac jar (`-p`, `-g`; a missing file is "No match." with
    status 0), `-P8VI.SYSTEM` typed at the prompt.  No sector leak here.
  - The plain ProDOS build's spare memory is $0800-$1fff after the
    variables (a2dos.spare_start): the key buffers go there, not off the
    text.
  - Maybe: 80 columns on a IIe (aux/main interleaved screen), the language
    card's 16 KB on DOS 3.3.
- **ProDOS 128 KB** (`p8vi-prodosx.sys`; src/prodosx: store_platform
  (the page store), pagemem_platform, auxmem).  The pages in aux
  $0800-$bfff through the firmware's AUXMOVE ($c311): two headers, 44
  pages of 1 KB; MACHID ($bf98) says 128 KB, else it says it needs 128 KB
  and ends (main RAM has less than a page after it).  ProDOS's /RAM, in
  the same memory, is disconnected (tech note 8: out of DEVLST, NODEV in
  its vector); the next boot puts it back.  The page store uses fastmem
  whatever FAST says, so the Apple builds now have src/fastmem.p8 (6502),
  not the TRS-80's stubs (src/appleii/fastmem_platform.p8).
  - Room: 39.3 KB of code ($2000-$b9b5), 4.3 KB of variables at $0800:
    one slot (in the spare memory below $2000), the scratch buffer after
    the code.  More slots would need room: fewer features, or the slots'
    page size smaller.
  - The sync's clock (platform.ticks) is the count of idle keyboard polls
    / 16: the Apple has none.
  - Tests (a2test.py --prodosx): files (with the page store suites, not
    huge or bigundo: more than 44 pages), screen, number: all pass.  Not
    yet: :rec after a reset (bobbin's reset is in its debugger, not in
    --simple), and /RAM's next format may overwrite the headers.
- **Atari 8-bit** (`p8vi-atari.xex`, `make atari`; p8c's atari target;
  src/atari with src/trs80's charset and store, the 6502 fastmem).  For
  $2000; every feature: 29.3 KB of code, 1.3 KB of variables, 9.2 KB of
  text up to MEMTOP; the key buffers below the program (MEMLO to $2000).
  The 40 x 24 screen (SAVMSC) written as screen codes, the cursor in
  inverse (the OS's off, CRSINH), the : line through E:.  Keys: the
  arrows $1c-$1f, RETURN $9b, BACK SPACE $7e and CTRL DELETE $fe as DEL,
  BREAK (BRKKEY) as RUN/STOP.  The clock for blinking is RTCLOK.
  - ATASCII text: lines end with $9b.  The editor has that as a fourth
    line ending, ENDING_ATASCII, kept as it is in memory (buffer.eol), and
    `:set atascii`; a platform's ATASCII_EOL is $9b here, 0 elsewhere
    (14 bytes in the other builds: the option's name).  New files get it.
  - ATASCII has no ~: the empty rows show '-'.
  - Tests (`make test-atari`, tests/atari/atest.py): files, screen,
    number, all pass, about a second each: atari800 -turbo with SDL's
    dummy drivers (no window), the host device as D: (-Hdevicename D -H1
    dir -hreadwrite), started in its monitor with a breakpoint at
    sys.exit, then quit.  So no DOS in the tests: the CIO calls are the
    same.  (atr/dos2fs corrupted the DOS25.XFD at hand; dir2atr's images
    work.)
  - Tried by hand under DOS 2.5 in atari800 (2026-11-26): P8VI.XEX on D2:
    (a dir2atr image) loaded with DUP's L, edited, saved to D1: and back
    to DOS.  :w d2:name saved as a file "D2": diskio.rename gave DOS
    "D2:P8VI.TMP,D2:NAME" and DOS 2.5 takes the new name up to its ':'.
    Fixed in p8p8's library (diskio.rename leaves the new name's device
    off).  Checked with :w d1:t2.txt (twice: over the file too) on the
    800XL and 130XE builds; atari800's H: had the same result as DOS 2.5
    before the fix.  Now in the file suites: edtest's prefix suite, with
    each machine's own prefix (trstest.prefix_suite: d1: here, c: on
    MS-DOS and the ST, a: on CP/M, ./ on the host, : on the Amiga, the
    volume on ProDOS and the Macintosh), in every build with
    features.PREFIX.
- **Atari 130XE** (`p8vi-atarixe.xex`; src/atarixe: store_platform (the
  page store), pagemem_platform, xebank).  The extra 64 KB is four banks
  of 16 KB at $4000-$7fff (PORTB bits 2-3, bit 4 0 for the CPU, bit 5 left
  1 for ANTIC): two headers and 62 pages of 1 KB.  p8vi's code runs
  through the window, so the copy loop (40 bytes) is copied to page 6
  ($0680, after the virtual registers) and runs from there: bank in, copy
  between the window and the slots (above $8000 or below $2000), PORTB
  back, return.  The banks are found by reading bank 0 through the window:
  on a 64 KB XL that is the program's own code (no test writes: they'd
  land on it); without them it says it needs a 130XE.
  - Room: the page store's code is 36.3 KB with SPLASH, SCROLL, NUMBER,
    MARKS and Z_VIEW off (about 2.3 KB, the user's choice of what to drop),
    1.7 KB of variables, 1.9 KB left for the slot and the scratch buffer.
  - Tests (atest.py --xe, on atari800's -xe): files with the page store
    suites (not huge, bigundo: more than 62 pages; not marks, zview) and
    screen pass.  Not yet: :rec after a reset; DOS 2.5's RAMDISK.COM uses
    the same banks (D8:), not checked for.
- **Atari ST** (`p8vi-atarist.tos`, `make atarist`; p8c's atarist target,
  started 2026-11-26).  Built as the Amiga is: the wide core from
  copies (encode_copy.py --wide --bytewise, build/stwide), src/cpm's
  screen (txt.term VT52: the ST's console is a VT-52), src/trs80's
  charset and store, src/m68k's strings (moved there from src/amiga), and
  the library's diskio (GEMDOS handles).  src/atarist:
  - console_platform: output buffered and sent with the BIOS's Bconout
    (device 2), not GEMDOS: GEMDOS's console output checks for ^S and ^C
    with Bconin, which takes typed keys (a Ctrl-C would end p8vi).  Keys
    from Bconin, the arrows, Clr/Home and Undo by their scan codes
    (Shift-up and -down: Kbshift, as Ctrl-B and Ctrl-F).  Wrap off while
    p8vi runs (ESC w), so the last column can be written.
  - platform: the text is the largest Malloc block less 16 KB (Mfree at
    the end); the screen is 80 x 25, or 40 x 25 in the low resolution
    (tos.rez); `p8vi [file]` from sys.argv (more than one argument or an
    option: a usage line); CR LF for new files; paths with `\`.
  - Tests (`make test-atarist`, tests/atarist/sttest.py): files 19,
    screen 18 (high and low), number 22, endings 2, args 7 (through
    tests/atarist/argsrun.p8: Pexec with a command tail, Hatari's --auto
    has none) and big (1.3 MB, 70000 lines, edits past line 65535, 25 s)
    pass on TOS 1.04, and files and screen on EmuTOS.  The screen is what
    p8vi sends (OUT.LOG, played back by termplay.py as VT-52); the real
    screen checked by hand from Hatari's screen memory (savebin $3f8000:
    its screenshots lag a few frames).
  - Tried by hand in Hatari from the desktop (2026-11-26): as P8VI.TOS,
    text typed and saved; as P8VI.TTP with a file as its parameter, which
    it opened.
  - Not yet: tried on real hardware, or as an installed application for
    .TXT files; the ST's characters above 127 (umlauts)
    show as '.' (src/cpm/textio's put); the medium resolution is only in
    the screen suites' --rez med.
- **Classic Macintosh** (`p8vi-macplus.bin`, `make macplus`; p8c's macplus
  target, started 2026-11-26).  The wide core from copies (build/macwide,
  as the ST's), src/trs80's charset and store, src/m68k's strings, the
  library's diskio (the File Manager) and txt (its window, 80 x 25 in
  Monaco 9): not src/cpm's screen.  src/macplus/platform.p8:
  - The editor's rows go into the window directly, as the DOS version's
    into the video RAM: put_row fills macos.screen's row and draws it with
    one DrawText; scroll_rows is ScrollRect and row copies.  DOS_CURSOR:
    the cursor is the library's txt position, inverted and blinking while
    a key is waited for.
  - Keys from the system's events, read in the platform (not txt.chrin,
    which makes Return a newline and command keys the menus'): the arrows
    by their characters, Enter/Clear and command-[ Escape, command and a
    letter its control code, command-period RUN/STOP; Home, Page Up and
    Down by key code.  The menu's Quit and command-Q type Escape and :q.
    Clicks and updates as the library's (desk accessories, dragging).
  - The text: _MaxMem less 32 KB, _NewPtr (DisposPtr at the end).
    macos.quit_at_end, so the window doesn't wait for a key at the end.
    The Finder's document (AppParmHandle's first file): its folder made
    the current one (HSetVol with its working directory), then :e name.
    New files CR, TeachText's (TEXT/ttxt).
  - Tests (`make test-macplus`, tests/macplus/mactest.py, MAME macplus
    without a window, p8vi as the Finder on a copy of System 6.0.8's
    System Tools disk, files in and out with hfsutils): files 19, screen
    18 (the window's characters, SCREENn.BIN at $ff), number 22, endings
    2 pass.  MAME runs on two seconds after the program's end (P8P8DONE
    in Scratch8), or the last track written may not be in the image.  On
    System 4.2 (the "System 5.0" disk) 4 screen suites lose the first
    block of a screen dump (NULs on the disk): not seen with 6.0.8.
  - Tried by hand (2026-11-26): a document selected with p8vi and
    opened from the Finder loads; :w to a Disk:Folder:file path saves;
    under System 7.5.5 (MultiFinder) Get Info's 304 KB preferred size is
    what About This Macintosh shows, and Ctrl-G's room fits it.
  - Not yet: tried on real hardware; the menus and desk accessories
    checked one by one; a big-file test (a 800 KB disk holds no 1.3 MB file: a hard
    disk image); characters above 127 are shown (Mac Roman) but can't be
    typed (option keys are dropped: the editor's codes above 127 are
    keys); the window's size is the library's (80 x 25, not resizable).
- **Host version** (`build/p8vi-host`, `make host`; llvm64 and clang;
  src/host with src/cpm's screen and src/trs80's charset).  A program for
  this machine in a terminal: `p8vi-host [-t ansi|vt52|adm3a] [-40]
  [-s COLSxROWS] [file]`.  The terminal is the console (src/host/console_platform.p8:
  the library's getkey/waitkey syscalls, raw mode from the first key);
  src/cpm/console_platform.p8 is CP/M's.  New files get LF; the safe
  save's p8vi.tmp goes in the file's directory (PATH_SEP '/').  Checked
  on macOS (arm64), 2026-11-10: edtest's file suites (19) and screen
  suites (18, on the three terminals) pass with the keys piped in (a
  scratch run of tests/cpm/cpmtest.py), and in a pty a lone ESC, Ctrl-C
  and :wq work.  `make test-host` runs them (cpmtest.py --host: the keys
  on stdin; the screen compared is the one before :q! clears it).  The
  runtime's waitkey flushes stdout before it waits since the compiler of
  2026-11-11 (bugs/llvm64_waitkey_flush.md): an older one shows no
  screen.  Open:
  - The screen is the terminal window's size, up to 250 x 200
    (console.MAX_WIDTH/MAX_HEIGHT; the editor's rows and columns are
    ubytes), and follows it: the runtime's size (syscall 219, the
    library's txt.terminal_size(): TIOCGWINSZ, GetConsoleScreenBufferInfo;
    bugs/llvm_terminal_size.md), looked at every 60th of a second while
    p8vi waits for a key (console.wait: the runtime's waitkey doesn't wake
    up for a resize; no CPU time to speak of).  A new size lays the screen
    out again (platform.SWITCH, as the C128's 40/80 key).  stdout not a
    terminal: 80 x 24; `-s COLSxROWS` gives a size instead.  Tested:
    cpmtest.py --host size (in a pty: the size at the start, made bigger
    and smaller, with no key after it, :set number, bigger than 250 x 200;
    against -s runs of the same size).  On Windows it follows the window
    in Windows Terminal and over ssh to Windows' sshd (the user,
    2026-11-11).  (before, cac5e53, p8vi asked the terminal with
    ESC [ 6 n, and only Ctrl-L looked again)
  - Arrow keys: the runtime's getkey gives the arrows' codes itself
    (ESC [ A, ESC [ 1;2A, ESC O A: the same as the editor's); Home, Page
    Up/Down, unknown sequences and VT52 are txt.escape_key's.  Tested by
    cpmtest.py --host's ansi-keys and vt52-keys suites.
  - llvm32 (wasm with WASI: no raw keyboard there) and Linux builds not
    tried; Windows builds (the user, 2026-11-11).
- **Amiga** (amiga500 target, Kickstart 1.3 and later; started
  2026-11-11; in `release/` since v0.5, p8vi-amiga and its icon).  The plan: the console is an ANSI terminal like the host's
  and CP/M's (src/cpm/textio.p8), with the wide core (32-bit positions).
  p8vi's own modules first (src/amiga: console, diskio), in the style of
  the library's for the other targets, dropped when the compiler has
  them.  Step 1 done: tests/amiga/keyecho.p8 (make emu-amiga-keyecho) on
  an A500 in Copperline, Kickstart 1.3 and AROS:
  - raw mode on 1.3: the ACTION_SCREEN_MODE packet (Arg1 DOSTRUE, 0 back
    to cooked) to the console handler (the Input() FileHandle's Type),
    replied to the process's pr_MsgPort (dos.SetMode and DoPkt are 2.0);
    keys with dos.WaitForChar (microseconds) and dos.Read;
  - the keys: arrows CSI A B C D (up down right left), Help CSI ? ~, F1
    CSI 0 ~, Esc 1B, Del 7F, Backspace 08, Ctrl-C 03 (a key in raw mode).
    CSI is the 8-bit $9B: txt.escape_key must take it as ESC [;
  - the window's size: CSI 0 SPACE q answers CSI 1 ; 1 ; rows ; cols
    SPACE r ($9B too): 20 x 61 on 1.3's first CLI window, 29 x 77 on
    AROS;
  - txt.print_ub and the like need 2.0 (VPrintf, an alert on 1.3); conv
    (exec.RawDoFmt) works;
  - Copperline automates it: --run PROG, --type-after, --press-after
    (raw key codes: $4C up, $5F Help ...), --screenshot-after,
    --exit-on-return; a JSON-RPC control server (--control).
  Step 2 done (2026-11-11): p8vi runs (build/p8vi-amiga, make amiga,
  make emu-amiga), and edtest's 19 file suites pass on Kickstart 1.3 and
  AROS (make test-amiga, tests/amiga/amigatest.py: the test build plays
  keys.txt, Copperline's --run with --exit-on-return, about 15 s).
  - src/amiga/console_platform.p8: raw mode, keys (WaitForChar, Read),
    output kept in a buffer and written before waiting for a key, the
    window's size asked at the start (CSI 0 SPACE q).  txt doesn't ask
    for keys while it sends the screen when the console keeps them
    (console.KEEPS_KEYS: each ask is a packet here).
  - src/amiga/diskio.p8: the library's diskio calls p8vi uses, over
    dos.library, in the llvm targets' style; src/amiga/strings_platform.p8
    the m68k strings' missing rfind and append (merged into strings).
    Both to drop when the compiler's library has them.
  - The 68000 stops with an address error on a word or long at an odd
    address: the wide core's undo records put positions anywhere, so
    the Amiga's copies read and write them a byte at a time
    (encode_copy.py --bytewise: pos.load, pos.store), and sys.memset
    becomes pos.memset (the m68k count is a uword).  (msb() of a long
    is its top byte: pos.store's first version got bits 8-15 wrong,
    which the zview suite found)
  - txt.escape_key reads a CSI sequence to its final byte (Help is
    CSI ? ~, shift left CSI SPACE A); the Amiga's shift up and down
    (CSI T, CSI S) page.  $9B is ESC [ (get_key).
  - Paths: PATH_VOLUME ':' (df0:name) ends a prefix too, for the safe
    save's p8vi.tmp.
  - The text: the largest free block (exec.AvailMem MEMF_LARGEST) less
    32 KB, freed at the end.  The file name and -s from sys.arguments.
  Window resizes (done, 2026-11-11): console.start() sends CSI 12 { (raw
  events of class 12), and the console puts CSI 12;0;0;qualifiers;x;y;
  seconds;micros | in with the keys once a resize ends (Kickstart 1.3
  too; tests/amiga/keyecho.p8 shows it).  The console reads a CSI
  sequence whole (up to 48 bytes: the report is about 30), takes a report
  out (console.resized, no key: the host's path, platform.SWITCH) and
  passes others on byte by byte; then CSI 0 SPACE q gives the new size.
  No polling: the report wakes the Read.  CSI 12 } at the end.  A resize
  clears txt (txt.cls, on the host too: the status row was a text row of
  the old layout, and kept its text).  make test-amiga --resize (1.3):
  Copperline drags the size gadget (--mouse-to-after takes the 716 x 540
  screenshot's coordinates), then L x :w shows the rows p8vi uses.
  Screen suites (done, 2026-11-11): the test build's output goes to a
  file (the CLI's redirection, p8vi.com >out.log: Copperline's
  --run-args go through the CLI, and the file is on the host), keys
  still from the window; tests/cpm/termplay.py plays it back as on CP/M
  (amigatest.py screen, number: 18 and 22 pass; with scroll_rows broken
  the scroll suites fail).  With the output a file the console doesn't
  ask the window's size (80 x 24) or for resize reports.  This checks
  what p8vi sends, not how console.device draws it: for that, native
  screenshots read as text (Topaz 8 is a fixed 8 x 8 font on an 8 pixel
  grid: cells matched exactly against its glyphs), not done.
  Started from Workbench (done, 2026-11-11): with no console (Input() 0,
  or <NIL:) p8vi opens a window of its own (CON:0/0/640/200/p8vi), keys
  and screen there, closed at :q; from a Shell it edits in the Shell's
  window.  The file comes from the Workbench message Prog8's start-up
  code keeps (p8_sys_startup.WBMsg: a WBStartup, sm_NumArgs at 28,
  sm_ArgList at 36; WBArg 1 is the project or shift-clicked file), opened
  in its drawer (CurrentDir, put back at the end); with none, p8vi's own
  drawer.  Tested from the CLI with <NIL: (amigatest.py --own-window:
  files in its own window, in make test-amiga); not from Workbench yet.
  Icons (tools/mkicon.py, in the classic 1.3 format every Workbench
  reads): make amiga makes build/p8vi-amiga.info (a tool icon: a small
  terminal with an orange "vi", 40 x 20, 2 bitplanes, 8 KB stack); make
  emu-amiga puts p8vi.info and sample.txt.info (a project, its default
  tool p8vi) in build/amiga.  Read back with icon.library on AROS (type,
  stack, image, default tool); 1.3's icon.library is on the Workbench
  disk (LIBS:), not in Copperline's --run boot.
  On Workbench 1.3 (make emu-amiga-wb: workbench-135.hdf on copperhf,
  build/amiga as the volume p8vi:, 2026-11-12): the icons show; double-
  clicking p8vi opens its window with the start screen; double-clicking
  sample.txt opens it in p8vi (1.3 finds the default tool p8vi, given
  without a path, in the project's drawer).  The user tried it too.
  A file selected, then p8vi double-clicked with Shift held, opens that
  file (other.txt, whose own default tool was ed).  Still to do:
  Workbench 2.0+.
  Next: try a real A500.
- **Color Computer 2 and 3** (`p8vi-coco.bin`, `p8vi-coco3.bin`; src/coco,
  src/coco3; p8c's coco2ram and coco3ram targets, the CoCo 2 with
  `-varshigh 0`).  DECB programs for `LOADM"P8VI":EXEC` under Disk BASIC:
  the CoCo 2 (or 1) with 64 KB in all-RAM mode, on the 32 x 16 screen (small
  letters as inverse capitals); the CoCo 3 on the 80 x 24 screen (`WIDTH
  80`, put back at the end).  The gap buffer: 28354 bytes free on the CoCo
  2, 27123 on the CoCo 3 (in XRoar).  Keys: BREAK is Esc, `@` then a letter
  is Ctrl (features.CTRL_AT), ← is Backspace; files are Disk BASIC's
  (T.TXT, a drive number after the name), new ones with CR.  No disk
  commands, recovery or `:set ascii`.  Tested: make test-coco and
  test-coco3 (tests/coco/cocotest.py, tests/coco3/coco3test.py: XRoar
  headless, toolshed's decb for the disk images), the file suites pass; a
  disk made with `decb copy -2 p8vi-coco.bin disk.dsk,P8VI.BIN` loads and
  runs in XRoar (the user, 2026-11-23).  Still to do: real hardware (a
  friend of the user's has a CoCo), the screen suites.  (before p8c the
  6809's code from llvm16's mc6809-coco was 4.5 times the Z80's:
  bugs/mc6809_code_size.md)

## Tests

- **A VIC-20 test runner** (with `xvic`).  `tests/vice/edtest.py` runs the
  C64, the PET (`--machine pet`), the Plus/4 (`--machine plus4`) and the
  C128 (`--machine c128`, `c128-80`).
- **cx16 tests.**  x16emu can only type keys by pasting text with `-bas`,
  so tests there are done by hand so far.
- **Intermittent failures with JiffyDOS** (`make test-jiffydos`): in 2
  of 3 full runs, suites of the REU and font builds failed (an extra byte
  at the end of a file read in, lines missing after a put, a hang), and
  in 1 of 10 runs of three suites; the stock ROMs had none in 10.  Not
  reproduced in 55 later runs on a quieter machine, so maybe host load
  or another test run at the same time (the runner's files in `build/`
  have fixed names, vt-<suite>.*).  The disk and plain C64 builds passed
  every time.
- **Intermittent failures:** in 2 of 6 full PET screen runs one suite
  failed (not the same one); the MEGA65 runner fails with "no answer"
  when the machine is very busy (its monitor reads time out after 5 s).
