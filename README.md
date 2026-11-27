# Prog8 AI context for developing user programs

This repository uses reference material from the official Prog8 compiler
repository, downloaded by `setup.py`.  The AGENTS.md file references upstream
documents and adds additional information to help with writing programs with
Prog8 and inline 6502 assembly.

Some critical code sections like startup code for a target might be written
directly in 6502 assembly language in .asm files and included either by
the inline assembly directly or defined in the custom target properties file.

Prog8 code can easily load modules and call routines written directly in
6502 assembly, but the typical case would be Prog8 and some inline assembly.

The compiler source code is not downloaded, but the standard library source
code (written in Prog8) is critical.

The upstream compiler repository, under the GPLv3 license, is here:
https://github.com/irmen/prog8

`setup.py` does a sparse, shallow download of only the agent skills, docs,
grammar, standard library and example code, matching the version of the
installed `prog8c` compiler.  This gives AI agents the upstream context
without duplicating it here or checking out the whole compiler repository.

# p8vi

This repository holds p8vi, a vi for 8-bit computers written in Prog8.
`docs/QUICKSTART.md` is an introduction with a one-page cheat sheet,
`docs/KEYS.md` lists the vi commands it has, `docs/TODO.md` ideas for
later.

| Build | Toplevel file | Target |
|-------|---------------|--------|
| `build/p8vi-c64.prg` | `src/p8vi.p8` | C64 |
| `build/p8vi-c64reu.prg` | `src/p8vi_c64reu.p8` | C64 with the page store, for text in an REU |
| `build/p8vi-c64disk.prg` | `src/p8vi.p8` | An experiment: C64 with the page store, its pages in SEQ files (`p8vi.swp...`) on the drive, for fast devices (IDE64, RAMLink, CMD HD); `src/diskpage` |
| `build/p8vi-cx16.prg` | `src/p8vi_cx16.p8` | Commander X16, text in banked RAM (the page store) |
| `build/p8vi-cx16ovl.prg`, `build/p8vi-cx16isoovl.prg` | `src/p8vi_cx16ovl.p8`, `src/p8vi_cx16isoovl.p8` | The X16 builds with overlays (p8c's `%overlay`): part of the code in banked RAM, for room in main RAM; the `.prg` is a small loader that reads the `.non` of the same name from drive 8, so both go on the disk |
| `build/p8vi-cx16iso.prg` | `src/p8vi_cx16iso.p8` | Commander X16 in ISO mode: ASCII/ISO text shown as it is (`{ \| } ~ _`), file names in ISO; built from `%encoding iso` copies of the sources (`tools/encode_copy.py`, `bugs/encoding_option.md`), in progress |
| `build/p8vi-mega65.prg` | `src/p8vi_mega65.p8` | MEGA65 (MEGA65 mode), with the ASCII characters for ASCII files, in progress |
| `build/p8vi-mega65dma.prg` | `src/p8vi_mega65dma.p8` | The same with the page store: text in attic RAM (or chip RAM banks 4 and 5) through DMA, in progress |
| `build/p8vi-plus4.prg` | `src/p8vi_plus4.p8` | Plus/4: the full editor with 24.6 KB of text, running with the RAM in up to `$fc00` and the KERNAL ROM switched in for its calls (`src/plus4/rammode.p8`), in progress |
| `build/p8vi-pet32.prg` | `src/p8vi_pet32.p8` | PET 4032 (32 KB, BASIC 4), with the VIC-20's features and no ASCII or CR LF files: 3.3 KB of text, in progress |
| `build/p8vi-vic20.prg` | `src/p8vi_vic20.p8` | VIC-20 with 24K or more |
| `build/p8vi-c64font.prg` | `src/p8vi_c64font.p8` | An experiment: the C64 REU build with a font for ASCII text |
| `build/p8vi-c128.prg` | `src/p8vi_c128.p8` | C128 in its own mode, on the 40 or 80 column screen (the 40/80 key switches), in progress |
| `build/p8vi-c128x.prg` | `src/p8vi_c128x.p8` | C128 with the text in RAM bank 1 (the page store), up to about 60 KB; a font build too |
| `build/p8vi-c128reu.prg` | `src/p8vi_c128reu.p8` | C128 with the text in an REU, or RAM bank 1 without one |
| `build/p8vi-trs80.cmd` | `src/p8vi_trs80.p8` | TRS-80 Model III with LDOS (llvm16, the `z80-trs80-cmd` profile: needs llvm-z80 and z88dk), in progress |
| `build/p8vi-trs80m4.cmd` | `src/p8vi_trs80m4.p8` | TRS-80 Model 4 with TRSDOS 6 or LS-DOS 6.3, 80 columns, in progress |
| `build/p8vi-trs80m4x.cmd` | `src/p8vi_trs80m4x.p8` | TRS-80 Model 4 with 128 KB: the text in the second 64 KB (the page store) |
| `build/p8vi-cpm.com` | `src/p8vi_cpm.p8` | CP/M 2.2 or later on a Z80, with an ANSI, VT52 or ADM-3A terminal (`-t`), in progress |
| `build/p8vi-dos.exe` | `src/p8vi_dos.p8` | MS-DOS 2.0 or later on an 8086 or better (dosexe: the code in a 64 KB segment of its own, the variables and about 55 KB of text in another), 80 x 25 colour or monochrome text screen, `p8vi [file]`; `src/dos`, `make dos`, `make emu-dos` (DOSBox-X), in progress |
| `build/p8vi-appleii.bin` | `src/p8vi_appleii.p8` | Apple IIe, IIc or IIgs with DOS 3.3 (a binary file for `$0800`, `BRUN P8VI`): the 40 x 24 screen, T files, the VIC-20's smaller set of features and about 5 KB of text, as DOS 3.3 leaves a program `$0800-$95ff`; `src/appleii`, `make appleii`, `make emu-appleii` (bobbin), in progress |
| `build/p8vi-prodos.sys` | `src/p8vi_prodos.p8` | Apple IIe, IIc or IIgs with ProDOS: a system program (`P8VI.SYSTEM`, type SYS) with every feature and about 10 KB of text (its variables at `$0800-$1fff`, the text up to `$bf00`), paths (`/VOLUME/DIR/NAME`); `src/prodos` with `src/appleii`, `make emu-prodos` (bobbin, AppleCommander's `ac` jar: `AC_JAR`), in progress |
| `build/p8vi-prodosx.sys` | `src/p8vi_prodosx.p8` | The same for 128 KB (a IIe with an extended 80-column card, a IIc or a IIgs): the text in the auxiliary 64 KB (the page store, 44 pages of 1 KB, through the firmware's AUXMOVE; ProDOS's /RAM is disconnected), up to about 44 KB, and `:rec` after a reset; `src/prodosx`, in progress |
| `build/p8vi-atari.xex` | `src/p8vi_atari.p8` | Atari 8-bit with 48 KB or more (800, XL, XE; without BASIC) and a DOS: every feature, about 9 KB of text, the 40 x 24 screen, ATASCII text files (lines end with `$9b`, `:set atascii`), device prefixes (`D2:NAME.TXT`); `src/atari`, `make atari`, `make emu-atari` (atari800), in progress |
| `build/p8vi-atarixe.xex` | `src/p8vi_atarixe.p8` | Atari 130XE: the text in its extra 64 KB (the page store, 62 pages of 1 KB through PORTB's banks), up to about 62 KB, and `:rec` after a reset; without the start screen, one-row scrolling, `:set number`, marks and `zt` `zz` `zb` (no room for them with the page store); `src/atarixe`, in progress |
| `build/p8vi-host` | `src/p8vi_host.p8` | This machine (macOS, Linux, Windows) in a terminal (llvm64): the wide core (32-bit positions, 16 MB of text), the screen the terminal window's size and following it (`make host`) |
| `build/p8vi-coco.bin`, `build/p8vi-coco3.bin` | `src/p8vi_coco.p8`, `src/p8vi_coco3.p8` | Tandy Color Computer 2 (64 KB, all RAM) and 3 (80 columns), with Disk BASIC; `src/coco`, `src/coco3` |
| `build/p8vi-amiga` | `src/p8vi_amiga.p8` | Amiga (amiga500: a 68000, Kickstart 1.3 or later) in its Shell window, or a window of its own from Workbench: the console is an ANSI terminal, the screen follows the window's size; the wide core (32-bit positions), text in the largest free block of memory; `src/amiga` (console, diskio), `make amiga`, `make emu-amiga`, in progress |
| `build/p8vi-atarist.tos` | `src/p8vi_atarist.p8` | Atari ST (atarist: a 68000, TOS 1.04 or later, or EmuTOS), a GEMDOS program in the VT-52 console (`P8VI.TTP` asks for the file to edit): the 80 x 25 screen, 40 x 25 in the low resolution; the wide core (32-bit positions), text in the largest free block of memory; CR LF files, GEMDOS paths (`C:\DIR\NAME.TXT`); `src/atarist` with `src/m68k`'s strings, `make atarist`, `make emu-atarist` (Hatari), in progress |
| `build/p8vi-macplus.bin` | `src/p8vi_macplus.p8` | the classic Macintosh (macplus: a Macintosh Plus or later with a 68000 or better, System 4.1 or later), an application whose text is in a window of 80 x 25 (a MacBinary file: the application p8vi, built as `build/macapp/p8vi.bin`); the editor's rows drawn into the window directly, the keys from the system's events; the wide core, text in the largest free block of the application's heap; CR files (TeachText's), Macintosh paths (`Disk:Folder:name`); `src/macplus` with `src/m68k`'s strings, `make macplus`, `make emu-macplus` (MAME), in progress |

The editor itself is `src/editor.p8` (with `charset.p8`,
`src/<target>/platform.p8` and a text store, `buffer.p8` plus
`gapbuffer.p8` or `pagestore.p8`, chosen by `src/<target>/store_platform.p8`).
The two C64 builds differ only in the store: `p8vi-c64reu` is compiled
with `src/c64reu` before `src/c64`.  It keeps the text in pages in an
REU, up to 64 KB, or in main RAM without one (about 5 KB less than the
plain build).  The X16 keeps its pages in banked RAM
(`docs/XMEM-DESIGN.md`).  `p8vi-mega65dma` (`src/mega65dma` before
`src/mega65`) copies its pages to and from attic RAM with the DMA
controller, up to 254 pages of 1 KB (room for the store's 64 KB of text
with yank and undo besides), or chip RAM banks 4 and 5 (126 pages) on a MEGA65
without attic RAM, such as the Nexys4 boards (checked by model ID and by
writing to it).  Its program must end below `$c000`, so SPLASH, SUBST
and DIR are off there for now.  Each toplevel file has a `features` block
of `const bool` switches for optional features; the code of a feature that
is off is left out of the program.  The VIC-20 program has to end below
`$8000`, so its version leaves out features when room runs out: new
features that don't fit start out off there.  `make size` shows the room
left on each target.
`docs/FEATURE-SWITCHES.md` explains how the switches are written so the
compiler leaves the code out.
`docs/TEXT-STORE.md` lists the files to copy to use the text stores (the
gap buffer, or the page store with an REU or the X16's banked RAM) in
another program.

`p8vi-c64font` (the `FONT` switch, `src/c64/font.p8`) is the REU build
with OSCII (C64 OS + ASCII), a font that has the ASCII characters PETSCII
lacks: `` \ ^ _ ` { | } ~ ``.  It loads the font from `oscii.fnt` on the disk to the RAM under the
KERNAL at `$f800` and moves the screen to `$c800`, so the program and its
buffers end below `$c800`.  The characters are typed as in C64 OS: pound
`\`, up arrow `^`, left arrow `_`, and with Shift: `*` for `` ` ``, `+`
for `{`, pound for `|`, `-` for `}` and up arrow for `~`.  ASCII files are
translated to the PETSCII codes the font shows them for.  `make font`
makes `build/oscii.fnt` from the font in `FONTSRC` (`tools/mkfont.py`),
`make emu-c64font` runs it in VICE.  `p8vi-c128x` shows the same font.

The MEGA65 builds are font builds too (`src/mega65/font.p8`), with no
font file: the MEGA65 ROM has a lower case character set with the same
characters at the same codes (BASIC 65's `FONT A`, at `$29800`).  The
font follows the text: for an ASCII file p8vi copies that set into the
VIC-IV's character RAM with DMA, for a PETSCII file (and when it quits)
the C64 set (`$2d800`), so PETSCII graphics show as they are.  `:set
ascii` and `:set petscii` switch it too.  With the ASCII set the keys
are the same as on the C64 font build, and MEGA with `:`, `.`, `;` and
`,` types `{`, `|`, `}` and `~` too.

# Prerequisites

- **Java 17 or newer** to run the Prog8 compiler.  Check with `java -version`.
  [Adoptium](https://adoptium.net/temurin/releases) has OpenJDK builds for
  all platforms.
- **The Prog8 compiler**, run as `prog8c`.  Download `prog8c-<version>-all.jar`
  from the [Prog8 releases](https://github.com/irmen/prog8/releases), or see
  the [installation docs](https://prog8.readthedocs.io/en/latest/compiling.html)
  for other options.  Use v12.2 or newer.
- **The 64tass assembler**, which the compiler runs to assemble its output.
  Binaries are on [SourceForge](https://sourceforge.net/projects/tass64/files/binaries/),
  and most Linux distributions and Homebrew have a `64tass` package.
- **git**, **make** and **Python 3**.
- *Optional:* the [VICE emulator](https://vice-emu.sourceforge.io/) for
  `make emu` and the Commodore tests; x16emu, xmega65 (Xemu), trs80gp,
  tnylpo, XRoar (with toolshed's `decb`), [Copperline](https://copperline.dev/)
  [DOSBox-X](https://dosbox-x.com/), and bobbin (Micah Cowan's Apple II emulator)
  with dos33fsprogs' `dos33` and a DOS 3.3 disk image (`A2_DISK`), and
  for ProDOS java with AppleCommander's `ac` jar (`AC_JAR`), atari800,
  Hatari (with a TOS image, `ST_TOS`, or its EmuTOS), and MAME with
  hfsutils (with the Macintosh Plus's ROMs, `MAC_ROMS`, and a system disk,
  `MAC_SYSTEM`)
  for the X16, MEGA65, TRS-80, CP/M, Color Computer, Amiga, MS-DOS, Apple II, Atari, Atari ST and Macintosh versions'
  runs and tests.  `make test` runs on prog8c-llvm's virtual machine and
  needs no emulator.

p8vi's `Makefile` compiles every version with `p8c` (`PCC`): p8p8, a Prog8
compiler written in Prog8, which builds the Commodore, X16, MEGA65,
TRS-80, CP/M, Color Computer, Amiga, MS-DOS, Apple II, Atari, Atari ST, Macintosh and host versions, and writes the
virtual target's IR for prog8c-llvm's `-vm` (`VM`).  Each program is
compiled straight into its name (`-o`).
`setup.py` expects `prog8c` in your `PATH`.  If you
downloaded the jar, a small wrapper script does the job.  On Linux or macOS
save this as `prog8c` somewhere in your `PATH` and `chmod +x` it:
```
#!/bin/sh
exec java -jar /path/to/prog8c-12.3.4-all.jar "$@"
```
On Windows save this as `prog8c.cmd` in a folder on your `PATH`:
```
@java -jar C:\path\to\prog8c-12.3.4-all.jar %*
```

# Quick start

1. On GitHub click **Use this template** to create your own repository,
   then clone it.
2. Download the Prog8 reference material for your installed compiler:
   ```
   python3 setup.py
   ```
   (On Windows use `py setup.py` or `python setup.py`.)
3. Build and run the example program on the virtual target:
   ```
   make run
   ```
4. Start your AI coding assistant in the repository and ask it to write
   some Prog8!

`setup.py` puts the reference material in `.prog8-reference`, which is in
`.gitignore` so it is never committed.  Run it again whenever you install
a different version of the compiler.  It deletes and recreates the
directory each time.

The useful `make` targets are:

| Target       | What it does                                              |
|--------------|-----------------------------------------------------------|
| `make check` | Fast syntax check without compiling                       |
| `make run`   | Compile for the virtual target and run it                 |
| `make test` | The text store tests (the same as `make test-gap`): p8c writes their IR, prog8c-llvm's virtual machine runs it |
| `make test-all` | Every build's test suites, one after the other (an hour or more) |
| `make quick` | The quick tier for iterating: `make test`, `make size`, then one or two suites per build side by side (`tests/quick.py`, a few minutes; `make quick QUICK="c64 c128x"` for some builds) |
| `make test-gap` | Text store tests (gap buffer and page store) on the virtual target |
| `make test-c64` | Editor command tests on a C64 in VICE (`tests/vice/edtest.py`, ~10 s) |
| `make test-c64reu` | The same on the C64 REU build (the page store), with and without an REU, and recovery after a reset (`tests/vice/rectest.py`) |
| `make audit` | Look in the generated assembler for the silent compiler bugs found so far (`tools/asmaudit.py`) |
| `make test-fastmem` | The 6502 byte scans and copies (`src/fastmem.p8`) against plain Prog8, in VICE |
| `make bench` | Timings of the text store routines in VICE (`tests/bench/storebench.p8`), screenshots in `build/bench-*.png` |
| `make test-reu` | REU detection and reset tests in VICE (`tests/reu/`) |
| `make test-c64font` | The C64 REU build's tests on the font build, and its own (`font`) |
| `make test-c64disk` | The VICE editor and redraw tests on the C64 disk build, on a 1541 |
| `make test-c64-screen` | Check partial redraws against full redraws in VICE (~30 s) |
| `make test-plus4` | The VICE editor and redraw tests on a Plus/4 (`xplus4`, `tests/vice/edtest.py --machine plus4`) |
| `make emu-plus4` | Run the Plus/4 version in `xplus4`, with a disk of its own (`build/testplus4.d64`) |
| `make test-pet32` | The VICE editor and redraw tests on a PET 4032 (`xpet`, `tests/vice/edtest.py --machine pet`), without the suites for the features it leaves out |
| `make emu-pet32` | Run the PET version in `xpet`, with a disk of its own (`build/testpet.d64`) |
| `make test-mega65` | The VICE editor and redraw tests on a MEGA65 in xmega65, through `tools/m65harness.py` (`tests/mega65/edtest.py`, ~3 min) |
| `make test-mega65dma` | The same on the MEGA65 page store build, with the big-text and font suites, in attic RAM and (as on a Nexys4 board) without it |
| `make test-mega65-zp` | Which zero page bytes the MEGA65 ROM changes in KERNAL calls (`tests/mega65/zpwatch.p8`) |
| `make test-c128`, `test-c128x`, `test-c128reu` | The VICE editor and redraw tests on a C128 (`x128`), on both screens; the page store builds also with and without an REU, and recovery after a reset |
| `make test-trs80`, `test-trs80m4`, `test-trs80m4x` | The file suites on a TRS-80 in trs80gp (`tests/trs80/trstest.py`), and recovery (`tests/trs80/rectest.py`) on the Model 4 with 128 KB |
| `make test-cpm` | The file, screen, `:set number` and line range suites in tnylpo on its three terminals (`tests/cpm/cpmtest.py`), and on a TRS-80 Model 4's Montezuma CP/M in trs80gp (`tests/cpm/m4test.py`) |
| `make test-dos` | The file, screen and `:set number` suites on MS-DOS in DOSBox-X without a window (`tests/dos/dostest.py`, seconds): the screen after the keys against a full redraw, from the video RAM the test build writes to a file; `DOSMACHINE=hercules` (or `cga`, ...) picks DOSBox-X's machine |
| `make test-appleii` | The file and screen suites on an enhanced //e with DOS 3.3 in bobbin (`tests/appleii/a2test.py`, about a minute each): a copy of `A2_DISK` (by default `build/dos33.dsk`, e.g. the system master) with P8VI, the keys and the text put on with `dos33`; then with ProDOS (`--prodos`, seconds each), the `:set number` suites too, and the 128 KB build's (`--prodosx`, with the page store suites), on a copy of `PRODOS_DISK` (bobbin's ProDOS 2.4.2 disk) with AppleCommander (`AC_JAR`); each skipped without its tools or disk |
| `make test-atari` | The file, screen and `:set number` suites on an 800XL in atari800 without a window (`tests/atari/atest.py`, seconds): its host device as D:, a breakpoint at `sys.exit` in its monitor to end each run; then the 130XE build's (`--xe`, with the page store suites) |
| `make test-atarist` | The file, screen and `:set number` suites on a 4 MB ST with TOS 1.04 (`ST_TOS`, else EmuTOS) in Hatari without a window (`tests/atarist/sttest.py`, seconds): the directory as drive C:, the debugger ends each run at the program's Pterm; the screen from what the test build sends to the console (also written to `OUT.LOG`) played back as a VT-52 screen, in the high and the low resolution; a new text's line endings, the command line (through a parent program, `tests/atarist/argsrun.p8`) and a 1.3 MB file of 70000 lines |
| `make emu-atarist` | Run the Atari ST version in Hatari (`ST_TOS`, `ST_REZ`) with the samples on drive C: |
| `make test-macplus` | The file, screen and `:set number` suites, and a new text's line endings, on a Macintosh Plus in MAME without a window (`tests/macplus/mactest.py`, seconds each): p8vi as the Finder on a copy of a system disk (`MAC_SYSTEM`, System 6.0.8's System Tools by default; `MAC_ROMS` the ROMs), its files put on and read back with hfsutils; the screen from the window's characters the test build writes at a `$ff` key |
| `make emu-macplus` | Run the Macintosh version in MAME, on a copy of the system disk with p8vi and the samples |
| `make test-host` | The same suites for the host version with the keys piped in, a 4.5 MB file, and the window resized in a pty (`cpmtest.py --host`) |
| `make test-amiga` | `tests/vice/edtest.py`'s file and screen suites and the `:set number` ones on an A500 in Copperline, Kickstart 1.3 or AROS (`tests/amiga/amigatest.py`: the screen from p8vi's output redirected to a file, `p8vi >out.log`; ~1 min), and with 1.3 the window resized while p8vi runs |
| `make emu-amiga` | Run the Amiga version in Copperline with `sample.txt` |
| `make emu-amiga-wb` | Workbench 1.3 in Copperline (`AMIGA_WB_HDF`, by default FS-UAE's `workbench-135.hdf`) with `build/amiga` as the volume `p8vi:`: p8vi, its icon and a project icon for `sample.txt` |
| `make test-mega65-keymap` | Measure which MEGA65 keys give which PETSCII codes (the harness's key table) |
| `make size` | Memory map and room left for each build: `p8size` reads the `.p8map` that `p8c -map` writes beside each program (`p8size build/p8vi-c64.p8map` also shows where the bytes go, by block and subroutine; two maps compare them). The overlay builds use `p8c -meminfo` |
| `make disk` | `build/testgap.d81`: a 1581 disk with the C64 and VIC-20 programs, `oscii.fnt` and the sample files, for `make emu-c64`, `emu-c64reu`, `emu-c64font` and `emu-vic20` (drive 8 is a 1581) |
| `make c64`   | Compile for the C64 and run it in VICE                    |
| `make cx16`  | Compile for the Commander X16 and run it in x16emu        |
| `make test-coco`, `test-coco3` | The file suites on a Color Computer 2 and 3 in XRoar, headless (`tests/coco/cocotest.py`, `tests/coco3/coco3test.py`) |
| `make release` | Copy the programs (with the overlay builds' `.non` files), `oscii.fnt`, the Amiga's icon and `docs/QUICKSTART.md` to `release/` (after `make test`, `audit` and `size`): the last known good version.  Commit it, then push a tag that matches the splash's version (`git tag v0.6.0 && git push origin v0.6.0`): `.github/workflows/release.yml` makes a GitHub release with `release/` as `p8vi-v0.6.0.zip` |
| `make clean` | Remove everything in `build/`                             |

# How the AI context works

`AGENTS.md` is the single source of instructions for AI agents.  The other
agent files only point at it, so most tools pick it up without extra setup:

| File                              | Tool                       |
|-----------------------------------|----------------------------|
| `CLAUDE.md`                       | Claude Code                |
| `GEMINI.md`                       | Gemini CLI                 |
| `.github/copilot-instructions.md` | GitHub Copilot             |
| `.cursor/rules/prog8.mdc`         | Cursor                     |
| `.aiassistant/rules/AGENT_RULES.md` | JetBrains AI Assistant   |

`AGENTS.md` sends agents to the upstream skills, docs, grammar, standard
library and examples in `.prog8-reference`.  The files in `.context/` add
only what the upstream material doesn't already cover.  `setup.py` also
links the upstream skills into `.claude/skills/` so Claude Code loads them
automatically.

If the reference material is missing, `AGENTS.md` tells the agent to stop
and ask you to run `setup.py`.

# Customizing

- **A different compiler:** to match a beta or a locally built compiler
  (such as `prog8c-beta`), change `PROG8C` at the top of `setup.py`
  and `PCC` in the `Makefile` (`make PCC=...` for one run).  Snapshot builds are matched by commit, so
  for a compiler built from a fork or another branch also change
  `TARGET_REPO` and `TARGET_BRANCH`.
- **Your program:** source goes in `src/`, starting with the toplevel files `src/p8vi.p8` and `src/p8vi_vic20.p8`.
  Code for one target only goes in a target directory such as `src/c64/`.
  See `AGENTS.md` for the conventions.

# License

This template is released under the [0BSD license](LICENSE), so projects
created from it can use any license they like.  Replace `LICENSE` with
your own project's license, since the current one names the template's
author as the copyright holder.

The Prog8 material that `setup.py` downloads into `.prog8-reference` comes
from the [Prog8 repository](https://github.com/irmen/prog8) and is under
the GPLv3 license.  It is not part of this repository and is never
committed to it.
