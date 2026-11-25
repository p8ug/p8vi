#
# p8vi: a vi for 8-bit computers, written in Prog8.  This Makefile builds
# every version with p8c (p8p8, a Prog8 compiler written in Prog8: PCC),
# runs the tests and makes release/.
#
#   make                  every program (ALLPROGS: the release's and the host's)
#   make quick            the quick tests: one or two suites per build (tests/quick.py)
#   make test-all         every test suite of every build (an hour or more)
#   make release          the release's programs and QUICKSTART.md in release/
#   make test-NAME        one build's tests (test-c64, test-amiga ...), make test the virtual target's
#   make emu-NAME         run one build in its emulator
#   make size, audit      the 6502 builds' room left, and a look for known miscompiles
#

# Cross-platform commands (the Python command: python on Windows, python3
# elsewhere, make PYTHON=py for the Windows launcher.  Windows' copy, del and
# mkdir take the / in a path for an option, so there tools/fileop.py does
# their work.  p8c's -srcdirs takes : and ; alike)
ifeq ($(OS),Windows_NT)
    CP = $(PYTHON) $(FILEOP) cp
    RM = $(PYTHON) $(FILEOP) rm
    MD = $(PYTHON) $(FILEOP) mkdir
    PYTHON ?= python
else
    CP = cp -p
    RM = rm -fr
    MD = mkdir -p
    PYTHON ?= python3
endif

# the Python scripts the recipes run: their paths are here, not in the
# commands (forward slashes: Python takes them on Windows too)
EDTEST = tests/vice/edtest.py
RECTEST = tests/vice/rectest.py
CPMTEST = tests/cpm/cpmtest.py
M4TEST = tests/cpm/m4test.py
M65TEST = tests/mega65/edtest.py
M65KEYMAP = tests/mega65/keymap.py
TRSTEST = tests/trs80/trstest.py
TRSRECTEST = tests/trs80/rectest.py
REUTEST = tests/reu/reutest.py
AMIGATEST = tests/amiga/amigatest.py
COCOTEST = tests/coco/cocotest.py
COCO3TEST = tests/coco3/coco3test.py
QUICKTEST = tests/quick.py
ASMAUDIT = tools/asmaudit.py
MKFONT = tools/mkfont.py
MKICON = tools/mkicon.py
M4DISK = tools/cpm/m4disk.py
ENCODE_COPY = tools/encode_copy.py
FILEOP = tools/fileop.py

#
# the compiler and each build's options.  Every program is compiled straight
# into its name (-o: the .prg, and its .asm, .list, an overlay build's .non,
# all have that name; an overlay loader has it built in)
#
PCC = p8c
# the virtual target's programs (make test): p8c writes their IR, which
# prog8c-llvm's virtual machine runs
VM = prog8c-llvm -vm -quiet
# the TRS-80 and CP/M builds link with z88dk
Z88DK ?= $(HOME)/.local/z88dk
export Z88DK

# the C64: the full editor and the gap buffer (src/p8vi.p8); the REU build,
# the page store (src/c64reu before src/c64); the disk build, the page store
# with its pages in SEQ files on the drive (src/diskpage); the font build,
# the REU build with its own font (src/c64/font.p8)
PCCARGSC64 = -srcdirs "src:src/c64" -map -asmlist -target c64
PCCARGSC64REU = -srcdirs "src:src/c64reu:src/c64" -map -asmlist -target c64
PCCARGSC64DISK = -srcdirs "src:src/diskpage:src/c64" -map -asmlist -target c64
PCCARGSC64FONT = $(PCCARGSC64REU)
# the X16: the page store in banked RAM.  the ISO mode build compiles every
# module of the program with %encoding iso, from copies tools/encode_copy.py
# makes in build/cx16iso (the library keeps PETSCII; bugs/encoding_option.md)
PCCARGSCX16 = -srcdirs "src:src/cx16" -map -asmlist -target cx16
CX16ISO = build/cx16iso
CX16ISO_DIRS = src src/cx16
PCCARGSCX16ISO = -srcdirs "$(CX16ISO)/src:$(CX16ISO)/cx16" -map -asmlist -target cx16
# the MEGA65: the gap buffer, all features; the page store build, its pages
# in attic RAM (or chip RAM banks 4 and 5) through DMA
PCCARGSM65 = -srcdirs "src:src/mega65" -map -asmlist -target config/mega65.properties
PCCARGSM65DMA = -srcdirs "src:src/mega65dma:src/mega65" -map -asmlist -target config/mega65.properties
# the Plus/4: the full editor, running with the RAM in up to $fc00
PCCARGSPLUS4 = -srcdirs "src:src/plus4" -map -asmlist -target config/plus4.properties
# the C128 in its own mode, on the VIC-II or the VDC; the bank 1 build (the
# page store in RAM bank 1, a font build too); the REU build (an REU, or
# bank 1; src/c64 for its reu.p8)
PCCARGSC128 = -srcdirs "src:src/c128" -map -asmlist -target c128
PCCARGSC128X = -srcdirs "src:src/c128bank1:src/c128font:src/c128" -map -asmlist -target c128
PCCARGSC128REU = -srcdirs "src:src/c128reu:src/c128:src/c64" -map -asmlist -target c128
# the PET (32 KB, BASIC 4) and the VIC-20 (with 24 KB or more)
PCCARGSPET32 = -srcdirs "src:src/pet32" -map -asmlist -target pet32
PCCARGSVIC20 = -srcdirs "src:src/vic20" -map -asmlist -target config/vic20plus24.properties
# the TRS-80 Model III with LDOS; the Model 4 in its own mode (TRSDOS 6,
# LS-DOS 6.3); the Model 4 with 128 KB (the page store in the second 64 KB)
PCCARGSTRS80 = -srcdirs "src:src/trs80" -map -target trs80
PCCARGSTRS80M4 = -srcdirs "src:src/trs80m4:src/trs80" -map -target trs80m4
PCCARGSTRS80M4X = -srcdirs "src:src/trs80m4x:src/trs80m4:src/trs80" -map -target trs80m4
# CP/M 2.2 and later on a Z80, with a terminal (-t ansi, vt52 or adm3a): the
# cpm profile leaves z88dk's heap off, the link options turn it on (AMALLOC:
# from the program's end up toward the stack)
PCCARGSCPM = -srcdirs "src:src/cpm:src/trs80" -map -target cpm \
	-Xlink -pragma-define:CRT_HEAP_AMALLOC=1 -Xlink -pragma-define:CRT_HEAP_ENABLE=1
# the Color Computer 2 (64 KB, in all-RAM mode) and 3 (80 columns)
PCCARGSCOCO = -srcdirs "src:src/coco" -map -target coco2ram -varshigh 0
PCCARGSCOCO3 = -srcdirs "src:src/coco3:src/coco" -map -target coco3ram -varshigh 0
# the wide core (32-bit text positions, up to pos.TEXT_MAX): compiled from
# copies with uword made long (tools/encode_copy.py --wide), src/wide/postype.p8
# first.  the host (llvm64: this machine, in a terminal); the Amiga (amiga500:
# a 68000 and Kickstart 1.3), its undo records read a byte at a time
# (--bytewise: a 68000 long must be at an even address).  both with src/cpm's
# screen and src/trs80's charset, fastmem and store
WIDEMODS = editor,buffer,gapbuffer,fastmem_platform,charset_platform
WIDE_DIRS = src src/trs80
HOSTWIDE = build/hostwide
PCCARGSHOST = -srcdirs "src/wide:$(HOSTWIDE)/src:src/host:src/cpm:$(HOSTWIDE)/trs80" -target llvm64
AMIGAWIDE = build/amigawide
PCCARGSAMIGA = -srcdirs "src/wide:$(AMIGAWIDE)/src:src/amiga:src/cpm:$(AMIGAWIDE)/trs80" -map -target amiga500
# the virtual target (make test)
PCCARGSVM = -srcdirs "src:src/virtual" -target virtual

#
# the programs
#
# the release's (release/): an overlay build is its loader, name.prg, and
# name.non beside it
PROGS = build/p8vi-c64.prg build/p8vi-c64reu.prg build/p8vi-c64disk.prg build/p8vi-c64font.prg \
	build/p8vi-c128.prg build/p8vi-c128x.prg build/p8vi-c128reu.prg \
	build/p8vi-cx16.prg build/p8vi-cx16iso.prg build/p8vi-cx16ovl.prg build/p8vi-cx16isoovl.prg \
	build/p8vi-mega65.prg build/p8vi-mega65dma.prg build/p8vi-plus4.prg build/p8vi-pet32.prg build/p8vi-vic20.prg \
	build/p8vi-trs80.cmd build/p8vi-trs80m4.cmd build/p8vi-trs80m4x.cmd build/p8vi-cpm.com \
	build/p8vi-coco.bin build/p8vi-coco3.bin build/p8vi-amiga
# the host's (not in the release: built for this machine)
HOSTPROG = build/p8vi-host
ALLPROGS = $(PROGS) $(HOSTPROG)
# the test builds: they play the keys in a file first (features.KEYFILE)
TESTPROGS = build/p8vi-cpmtest.com build/p8vi-trs80test.cmd build/p8vi-trs80m4test.cmd build/p8vi-trs80m4xtest.cmd \
	build/p8vi-amigatest build/p8vi-cocotest.bin build/p8vi-coco3test.bin
# what the release has besides the programs
EXTRAS = build/oscii.fnt build/p8vi-amiga.info

# the sources every build depends on (the platform files of all of them)
SRCS = src/*.p8 src/*/*.p8

all: build $(ALLPROGS) $(EXTRAS)

build:
	$(MD) build

build/p8vi-c64.prg: src/p8vi.p8 $(SRCS)
	$(PCC) $(PCCARGSC64) -o $@ $<
build/p8vi-c64reu.prg: src/p8vi_c64reu.p8 $(SRCS)
	$(PCC) $(PCCARGSC64REU) -o $@ $<
build/p8vi-c64disk.prg: src/p8vi.p8 $(SRCS)
	$(PCC) $(PCCARGSC64DISK) -o $@ $<
build/p8vi-c64font.prg: src/p8vi_c64font.p8 $(SRCS) build/oscii.fnt
	$(PCC) $(PCCARGSC64FONT) -o $@ $<
build/p8vi-c128.prg: src/p8vi_c128.p8 $(SRCS)
	$(PCC) $(PCCARGSC128) -o $@ $<
build/p8vi-c128x.prg: src/p8vi_c128x.p8 $(SRCS)
	$(PCC) $(PCCARGSC128X) -o $@ $<
build/p8vi-c128reu.prg: src/p8vi_c128reu.p8 $(SRCS)
	$(PCC) $(PCCARGSC128REU) -o $@ $<
build/p8vi-cx16.prg: src/p8vi_cx16.p8 $(SRCS)
	$(PCC) $(PCCARGSCX16) -o $@ $<
# the X16 with overlays (p8c's %overlay): part of the code in banked RAM, for
# room in main RAM.  name.prg is a small loader that reads name.non (the
# program and its overlays) from drive 8, so both go on the disk
build/p8vi-cx16ovl.prg: src/p8vi_cx16ovl.p8 $(SRCS)
	$(PCC) $(PCCARGSCX16) -o $@ $<
build/p8vi-cx16iso.prg: src/p8vi_cx16iso.p8 $(SRCS) $(ENCODE_COPY)
	$(PYTHON) $(ENCODE_COPY) --encoding iso $(CX16ISO) $(CX16ISO_DIRS)
	$(PCC) $(PCCARGSCX16ISO) -o $@ $(CX16ISO)/src/p8vi_cx16iso.p8
build/p8vi-cx16isoovl.prg: src/p8vi_cx16isoovl.p8 $(SRCS) $(ENCODE_COPY)
	$(PYTHON) $(ENCODE_COPY) --encoding iso $(CX16ISO) $(CX16ISO_DIRS)
	$(PCC) $(PCCARGSCX16ISO) -o $@ $(CX16ISO)/src/p8vi_cx16isoovl.p8
build/p8vi-mega65.prg: src/p8vi_mega65.p8 $(SRCS) config/mega65.properties $(wildcard libraries/mega65/*.p8)
	$(PCC) $(PCCARGSM65) -o $@ $<
build/p8vi-mega65dma.prg: src/p8vi_mega65dma.p8 $(SRCS) config/mega65.properties $(wildcard libraries/mega65/*.p8)
	$(PCC) $(PCCARGSM65DMA) -o $@ $<
build/p8vi-plus4.prg: src/p8vi_plus4.p8 $(SRCS) config/plus4.properties $(wildcard libraries/plus4/*.p8)
	$(PCC) $(PCCARGSPLUS4) -o $@ $<
build/p8vi-pet32.prg: src/p8vi_pet32.p8 $(SRCS)
	$(PCC) $(PCCARGSPET32) -o $@ $<
build/p8vi-vic20.prg: src/p8vi_vic20.p8 $(SRCS) config/vic20plus24.properties
	$(PCC) $(PCCARGSVIC20) -o $@ $<
build/p8vi-trs80.cmd: src/p8vi_trs80.p8 $(SRCS)
	$(PCC) $(PCCARGSTRS80) -o $@ $<
build/p8vi-trs80test.cmd: src/p8vi_trs80test.p8 $(SRCS)
	$(PCC) $(PCCARGSTRS80) -o $@ $<
build/p8vi-trs80m4.cmd: src/p8vi_trs80m4.p8 $(SRCS)
	$(PCC) $(PCCARGSTRS80M4) -o $@ $<
build/p8vi-trs80m4test.cmd: src/p8vi_trs80m4test.p8 $(SRCS)
	$(PCC) $(PCCARGSTRS80M4) -o $@ $<
build/p8vi-trs80m4x.cmd: src/p8vi_trs80m4x.p8 $(SRCS)
	$(PCC) $(PCCARGSTRS80M4X) -o $@ $<
build/p8vi-trs80m4xtest.cmd: src/p8vi_trs80m4xtest.p8 $(SRCS)
	$(PCC) $(PCCARGSTRS80M4X) -o $@ $<
build/p8vi-cpm.com: src/p8vi_cpm.p8 $(SRCS)
	$(PCC) $(PCCARGSCPM) -o $@ $<
build/p8vi-cpmtest.com: src/p8vi_cpmtest.p8 $(SRCS)
	$(PCC) $(PCCARGSCPM) -o $@ $<
build/p8vi-coco.bin: src/p8vi_coco.p8 $(SRCS)
	$(PCC) $(PCCARGSCOCO) -o $@ $<
build/p8vi-cocotest.bin: src/p8vi_cocotest.p8 $(SRCS)
	$(PCC) $(PCCARGSCOCO) -o $@ $<
build/p8vi-coco3.bin: src/p8vi_coco3.p8 $(SRCS)
	$(PCC) $(PCCARGSCOCO3) -o $@ $<
build/p8vi-coco3test.bin: src/p8vi_coco3test.p8 $(SRCS)
	$(PCC) $(PCCARGSCOCO3) -o $@ $<
build/p8vi-host: src/p8vi_host.p8 $(SRCS) $(ENCODE_COPY)
	$(PYTHON) $(ENCODE_COPY) --wide $(WIDEMODS) $(HOSTWIDE) $(WIDE_DIRS)
	$(PCC) $(PCCARGSHOST) -o $@ $(HOSTWIDE)/src/p8vi_host.p8
build/p8vi-amiga: src/p8vi_amiga.p8 $(SRCS) $(ENCODE_COPY)
	$(PYTHON) $(ENCODE_COPY) --wide $(WIDEMODS) --bytewise $(AMIGAWIDE) $(WIDE_DIRS)
	$(PCC) $(PCCARGSAMIGA) -o $@ $(AMIGAWIDE)/src/p8vi_amiga.p8
build/p8vi-amigatest: src/p8vi_amigatest.p8 $(SRCS) $(ENCODE_COPY)
	$(PYTHON) $(ENCODE_COPY) --wide $(WIDEMODS) --bytewise $(AMIGAWIDE) $(WIDE_DIRS)
	$(PCC) $(PCCARGSAMIGA) -o $@ $(AMIGAWIDE)/src/p8vi_amigatest.p8

# the C64 font build's font (OSCII: C64 OS + ASCII), and the Amiga's
# Workbench icon (a tool icon, named as the program)
FONTSRC = src/c64/oscii.p8
font: build/oscii.fnt
build/oscii.fnt: $(FONTSRC) $(MKFONT)
	$(PYTHON) $(MKFONT) $(FONTSRC) $@
build/p8vi-amiga.info: $(MKICON)
	$(PYTHON) $(MKICON) tool $@

# one build by its name
c64: build/p8vi-c64.prg
cx16: build/p8vi-cx16.prg build/p8vi-cx16ovl.prg
trs80: build/p8vi-trs80.cmd
trs80m4: build/p8vi-trs80m4.cmd
trs80m4x: build/p8vi-trs80m4x.cmd
cpm: build/p8vi-cpm.com
coco: build/p8vi-coco.bin build/p8vi-coco3.bin
host: build/p8vi-host
amiga: build/p8vi-amiga build/p8vi-amiga.info

clean:
	$(RM) build/*

#
# the release: the programs (an overlay build's .non too), the font, the
# Amiga's icon and the quick start guide, in release/ (kept in git: the last
# known good version, whatever build/ holds).  make test, audit and size run
# first; make quick, or make test-all for a release that matters, before it
#
release: $(PROGS) $(EXTRAS) test audit size
	$(MD) release
	$(CP) $(PROGS) release
	$(CP) build/p8vi-cx16ovl.non build/p8vi-cx16isoovl.non release
	$(CP) $(EXTRAS) release
	$(CP) docs/QUICKSTART.md release

#
# running a build in its emulator
#

# the disk for the C64 and VIC-20 runs: a 1581 (800 KB) with the programs,
# the font and the samples
DISKTYPE = d81
DISKNAME = testgap
DISK = build/$(DISKNAME).$(DISKTYPE)
disk: build/p8vi-c64.prg build/p8vi-c64reu.prg build/p8vi-c64font.prg build/oscii.fnt build/p8vi-vic20.prg
	c1541 -format $(DISKNAME),52 $(DISKTYPE) $(DISK)
	c1541 -attach $(DISK) -write build/p8vi-c64.prg p8vi,p
	c1541 -attach $(DISK) -write build/p8vi-c64reu.prg p8vi-reu,p
	c1541 -attach $(DISK) -write build/p8vi-c64font.prg p8vi-font,p
	c1541 -attach $(DISK) -write build/oscii.fnt oscii.fnt,p
	c1541 -attach $(DISK) -write build/p8vi-vic20.prg p8vi-vic20,p
	c1541 -attach $(DISK) -write samples/sampbig.txt sampbig.txt,s
	c1541 -attach $(DISK) -write samples/sampmax.txt sampmax.txt,s
	c1541 -attach $(DISK) -write samples/sampsmall.txt sampsmall.txt,s
	c1541 -attach $(DISK) -write samples/sample.txt sample.txt,s
	c1541 -attach $(DISK) -write src/c64/font.p8 font.p8,s

# VICE: the C64 with JiffyDOS and a 512 KB REU, drive 8 the disk above
EMU_REU = -reu -reusize 512
EMU = x64sc -default -keymap 1 -model ntsc -kernal jiffykernal -8 $(DISK) -drive8type 1581 \
	-dos1541 jiffy1541II -dos1541II jiffy1541II -dos1571 jiffy1571 -dos1581 jiffy1581 $(EMU_REU) \
	-monitorfont "JetBrains Mono 16"
emu-c64: build/p8vi-c64.prg disk
	$(EMU) -autostartprgmode 1 $<
emu-c64reu: build/p8vi-c64reu.prg disk
	$(EMU) -autostartprgmode 1 $<
emu-c64font: build/p8vi-c64font.prg disk
	$(EMU) -autostartprgmode 1 $<
# (the disk build's swap files go on the test disk: a 1581 in VICE is slow)
emu-c64disk: build/p8vi-c64disk.prg disk
	$(EMU) -autostartprgmode 1 $<

EMUVIC = xvic -default -keymap 1 -model ntsc -memory all -8 $(DISK) -drive8type 1581 -monitorfont "JetBrains Mono 16"
emu-vic20: build/p8vi-vic20.prg disk
	$(EMUVIC) -autostartprgmode 1 $<

# the C128 in its own mode, with the test disk (oscii.fnt is on it, for
# p8vi-c128x): the 40 column screen, make emu-c128 C128COL=-80col for the 80
C128COL = -40col
EMU128 = x128 -default -keymap 1 -model ntsc $(C128COL) -8 $(DISK) -drive8type 1581 -monitorfont "JetBrains Mono 16"
emu-c128: build/p8vi-c128.prg disk
	$(EMU128) -autostartprgmode 1 $<
emu-c128x: build/p8vi-c128x.prg disk
	$(EMU128) -autostartprgmode 1 $<
emu-c128reu: build/p8vi-c128reu.prg disk
	$(EMU128) $(EMU_REU) -autostartprgmode 1 $<

# the PET (a 4032 with a 2031 drive) and the Plus/4 (a 1541), each with a
# .d64 of its own
PETDISK = build/testpet.d64
emu-pet32: build/p8vi-pet32.prg
	c1541 -format testpet,52 d64 $(PETDISK)
	c1541 -attach $(PETDISK) -write build/p8vi-pet32.prg p8vi,p
	c1541 -attach $(PETDISK) -write src/c64/font.p8 font.p8,s
	c1541 -attach $(PETDISK) -write README.md readme.md,s
	xpet -default -model 4032 -drive8type 2031 -8 $(PETDISK) -autostart $(PETDISK)
P4DISK = build/testplus4.d64
emu-plus4: build/p8vi-plus4.prg
	c1541 -format testplus4,52 d64 $(P4DISK)
	c1541 -attach $(P4DISK) -write build/p8vi-plus4.prg p8vi,p
	c1541 -attach $(P4DISK) -write samples/sample.txt sample.txt,s
	c1541 -attach $(P4DISK) -write samples/sampmax.txt sampmax.txt,s
	c1541 -attach $(P4DISK) -write src/c64/font.p8 font.p8,s
	xplus4 -default -drive8type 1541 -8 $(P4DISK) -autostart $(P4DISK)

# the X16, with the samples as drive 8 (build/x16; an overlay build's .non
# has to be there, beside its loader)
X16DIR = build/x16
EMUX16 = x16emu -debug -scale 2 -rtc -fsroot $(X16DIR) -run -prg
x16-dir:
	$(MD) $(X16DIR)
	$(CP) samples/*.txt $(X16DIR)
emu-cx16: build/p8vi-cx16.prg x16-dir
	$(CP) $< $(X16DIR)
	$(EMUX16) $(X16DIR)/p8vi-cx16.prg
emu-cx16iso: build/p8vi-cx16iso.prg x16-dir
	$(CP) $< $(X16DIR)
	$(EMUX16) $(X16DIR)/p8vi-cx16iso.prg
emu-cx16ovl: build/p8vi-cx16ovl.prg x16-dir
	$(CP) $< build/p8vi-cx16ovl.non $(X16DIR)
	$(EMUX16) $(X16DIR)/p8vi-cx16ovl.prg
emu-cx16isoovl: build/p8vi-cx16isoovl.prg x16-dir
	$(CP) $< build/p8vi-cx16isoovl.non $(X16DIR)
	$(EMUX16) $(X16DIR)/p8vi-cx16isoovl.prg

emu-mega65: build/p8vi-mega65.prg
	xmega65 -prg $<
emu-mega65dma: build/p8vi-mega65dma.prg
	xmega65 -prg $<

# the TRS-80s in trs80gp (TRS80GP, the path of its binary): it boots the
# DOS and runs p8vi itself, with its utility disk in drive 1 (FreHD's
# IMPORT2 and EXPORT2) and build/frehd as the FreHD's directory (p8vi and
# samples/).  "IMPORT2 sample.txt SAMPLE/TXT:1" brings in a sample, and
# "IMPORT2 p8vi.cmd P8VI/CMD:1" p8vi to run it again (changes to the
# built-in disks aren't kept).  the Model III with LDOS, the Model 4 with
# TRSDOS 6 (m4x: 128 KB)
TRS80GP ?= $(HOME)/Applications/trs80gp.app/Contents/MacOS/trs80gp
FREHD = build/frehd
TRS80RUN = -frehd -frehd_dir $(FREHD)
frehd-dir:
	$(MD) $(FREHD)
	$(CP) samples/*.txt $(FREHD)
emu-trs80: build/p8vi-trs80.cmd frehd-dir
	$(CP) $< $(FREHD)/p8vi.cmd
	$(TRS80GP) -m3 -ld -d1 :lu3 $(TRS80RUN) $<
emu-trs80m4: build/p8vi-trs80m4.cmd frehd-dir
	$(CP) $< $(FREHD)/p8vi.cmd
	$(TRS80GP) -m4 -d1 :lu4 $(TRS80RUN) $<
emu-trs80m4x: build/p8vi-trs80m4x.cmd frehd-dir
	$(CP) $< $(FREHD)/p8vi.cmd
	$(TRS80GP) -m4 -mem 128 -d1 :lu4 $(TRS80RUN) $<

# CP/M: tnylpo's full screen console (VT52 codes) in this terminal, in
# build/cpm with the samples (tnylpo's drive A is the directory; it only
# sees 8.3 names, so sampsmall.txt is sampsmal.txt too)
CPMDIR = build/cpm
emu-cpm: build/p8vi-cpm.com
	$(MD) $(CPMDIR)
	$(CP) samples/*.txt $(CPMDIR)
	$(CP) samples/sampsmall.txt $(CPMDIR)/sampsmal.txt
	$(CP) $< $(CPMDIR)/p8vi.com
	cd $(CPMDIR) && tnylpo -s -w p8vi -t vt52
# the TRS-80 Model 4 with Montezuma Micro CP/M 2.2 in trs80gp: drive A a
# copy of the system disk (CPM_DISK), drive B a new data disk with p8vi.com
# and samples (tools/cpm/m4disk.py; made again each time, so edits there
# aren't kept).  In CP/M: b: then p8vi -t adm3a.  The keyboard gives
# capitals until CAPS is pressed, and BREAK is Escape.
CPM_DISK ?= build/cpm222_work.dsk
emu-trs80m4-cpm: build/p8vi-cpm.com
	$(CP) $(CPM_DISK) build/cpm-m4-a.dsk
	$(PYTHON) -B $(M4DISK) $(CPM_DISK) build/cpm-m4-b.dsk build/p8vi-cpm.com:p8vi.com \
		samples/sample.txt samples/sampsmall.txt samples/sample6.txt samples/sampmax.txt
	$(TRS80GP) -m4 -mem 64 -d0 build/cpm-m4-a.dsk -d1 build/cpm-m4-b.dsk

# the Color Computers in XRoar: the CoCo 2 (64 KB) and the CoCo 3 (128 KB)
emu-coco: build/p8vi-coco.bin
	xroar -machine coco2bus -run $<
emu-coco3: build/p8vi-coco3.bin
	xroar -machine coco3 -ram 128 -run $<

# the Amiga on an A500 in Copperline, with Kickstart 1.3 if it's there (else
# Copperline's AROS), with the samples in its directory (build/amiga: also
# p8vi's icon and a project icon for sample.txt, its default tool p8vi)
AMIGA_ROM ?= $(wildcard $(HOME)/Documents/FS-UAE/Kickstarts/amiga-os-130.rom)
amiga-dir: build/p8vi-amiga build/p8vi-amiga.info
	$(MD) build/amiga
	$(CP) build/p8vi-amiga build/amiga/p8vi
	$(CP) build/p8vi-amiga.info build/amiga/p8vi.info
	$(CP) samples/*.txt build/amiga
	$(PYTHON) $(MKICON) project build/amiga/sample.txt.info p8vi
emu-amiga: amiga-dir
	cd build/amiga && copperline --model A500 --run p8vi --run-args sample.txt $(AMIGA_ROM)
# Workbench 1.3 in Copperline: an A500 (1 MB) booting AMIGA_WB_HDF on
# Copperline's own hard disk controller (copperhf: the A500 has no IDE),
# with build/amiga as the volume p8vi: (a host directory, live: the files
# p8vi writes land there).  Open the p8vi disk, then double-click p8vi or
# sample.txt.  The configuration is written to build/amiga-wb.toml
AMIGA_WB_HDF ?= $(HOME)/Documents/FS-UAE/Hard Drives/workbench-135.hdf
AMIGA_WB_ROM ?= $(HOME)/Documents/FS-UAE/Kickstarts/amiga-os-130.rom
emu-amiga-wb: amiga-dir
	$(PYTHON) -c "import sys; open('build/amiga-wb.toml', 'w').write('rom = \"%s\"\n\n[memory]\nchip = \"512K\"\nslow = \"512K\"\n\n[copperhf]\nunit0 = \"%s\"\n\n[[filesys]]\npath = \"%s\"\nvolume = \"p8vi\"\n' % tuple(a.replace('\\\\', '/') for a in sys.argv[1:]))" "$(AMIGA_WB_ROM)" "$(AMIGA_WB_HDF)" "$(abspath build/amiga)"
	copperline --config build/amiga-wb.toml --model A500
# the Amiga port's step 1: the console's keys in raw mode (tests/amiga/keyecho.p8)
emu-amiga-keyecho: build
	$(PCC) -target amiga500 -o build/keyecho tests/amiga/keyecho.p8
	copperline --model A500 --run build/keyecho $(AMIGA_ROM)

#
# the tests
#

# everything: the virtual target's, every build's suites (an hour or more)
TESTS = test test-host test-cpm test-c64 test-c64-screen test-c64reu test-c64disk test-c64font \
	test-c128 test-c128x test-c128reu test-pet32 test-plus4 test-mega65 test-mega65dma \
	test-trs80 test-trs80m4 test-trs80m4x test-amiga test-coco test-coco3
test-all: $(TESTS)

# the quick tier, for iterating: the virtual tests, the size checks, then one
# or two suites per build side by side (tests/quick.py, a few minutes).  only
# some builds: make quick QUICK="c64 c128x" (tests/quick.py --list shows them)
quick: $(ALLPROGS) $(TESTPROGS) build/oscii.fnt test size
	$(PYTHON) -B $(QUICKTEST) $(QUICK)

# the text store tests (the gap buffer and the page store) on the virtual
# target, their output compared with tests/expected/
test: test-gap
test-gap: build
	$(PCC) $(PCCARGSVM) -ir -out build src/gaptest.p8
	$(VM) build/gaptest.p8ir | grep -v 'INFO\|WARN' | diff -u tests/expected/virtual_gaptest.txt -
	$(PCC) $(PCCARGSVM) -ir -out build src/pagetest.p8
	$(VM) build/pagetest.p8ir | grep -v 'INFO\|WARN' | diff -u tests/expected/virtual_pagetest.txt -

# the host version: edtest's file and screen suites with the keys piped in
# (tests/cpm/cpmtest.py --host); :set number, :d and :y with ranges, a 4.5
# MB file, the screen the terminal's size, new files' line endings
test-host: build/p8vi-host
	$(PYTHON) -B $(CPMTEST) --host files
	$(PYTHON) -B $(CPMTEST) --host screen
	$(PYTHON) -B $(CPMTEST) --host number
	$(PYTHON) -B $(CPMTEST) --host lines
	$(PYTHON) -B $(CPMTEST) --host big
	$(PYTHON) -B $(CPMTEST) --host size
	$(PYTHON) -B $(CPMTEST) --host endings

# CP/M in tnylpo (skipped without it): the file suites, and the screen
# suites on each terminal (tests/cpm/cpmtest.py); then the TRS-80 Model 4
# with Montezuma Micro CP/M in trs80gp, if its disk image is there
# (tests/cpm/m4test.py: CPM_DISK, or build/cpm222_work.dsk)
test-cpm: build/p8vi-cpmtest.com build/p8vi-cpm.com
	$(PYTHON) -B $(CPMTEST) files
	$(PYTHON) -B $(CPMTEST) screen
	$(PYTHON) -B $(CPMTEST) number
	$(PYTHON) -B $(CPMTEST) lines
	$(PYTHON) -B $(CPMTEST) endings
	$(PYTHON) -B $(M4TEST)

# the C64 in VICE (x64sc and c1541 in the PATH): the file suites; the screen
# suites (partial redraws must leave the same screen as a full redraw)
test-c64: build/p8vi-c64.prg
	$(PYTHON) -B $(EDTEST) files --prg $<
test-c64-screen: build/p8vi-c64.prg
	$(PYTHON) -B $(EDTEST) screen --prg $<

# the C64 REU build (the page store), with an REU and without one (then it
# has 4 KB of text: not the big file suite), and recovery after a reset
test-c64reu: build/p8vi-c64reu.prg
	$(PYTHON) -B $(EDTEST) files --prg $< --reu 512 --limit 3000000000
	$(PYTHON) -B $(EDTEST) files --prg $< --skip big
	$(PYTHON) -B $(RECTEST) --prg $<
	$(PYTHON) -B $(EDTEST) screen --prg $< --reu 512

# the C64 disk build (pages in SEQ files on the 1541), with the REU suites'
# 6 KB text (--paged).  huge and bigundo are left out: their 30-64 KB of text
# and its pages don't fit on a 1541 disk beside the program
test-c64disk: build/p8vi-c64disk.prg
	$(PYTHON) -B $(EDTEST) files --prg $< --paged --limit 3000000000 --skip huge --skip bigundo
	$(PYTHON) -B $(EDTEST) screen --prg $<

# the font build: the REU build's tests, and its own (the font suite).  it
# has its own keys for | (and } is shift + minus), its own PETSCII for ASCII
# files and oscii.fnt on the disk, so g-cmds, ascii and read-dir don't apply,
# and marks and zview: it has neither (features.MARKS, Z_VIEW)
FONT_SKIP = --skip g-cmds --skip ascii --skip read-dir --skip marks --skip zview
test-c64font: build/p8vi-c64font.prg build/oscii.fnt
	$(PYTHON) -B $(EDTEST) files --prg $< --font build/oscii.fnt --reu 512 --limit 3000000000 $(FONT_SKIP)
	$(PYTHON) -B $(EDTEST) files --prg $< --font build/oscii.fnt --skip big $(FONT_SKIP)
	$(PYTHON) -B $(RECTEST) --prg $< --font build/oscii.fnt
	$(PYTHON) -B $(EDTEST) screen --prg $< --font build/oscii.fnt --reu 512

# the C64 tests with JiffyDOS (VICE's jiffykernal and jiffy1541II ROMs, in
# its ROM directories), to compare with the ones above
JIFFY = --jiffydos
test-c64-jiffydos: build/p8vi-c64.prg
	$(PYTHON) -B $(EDTEST) files $(JIFFY) --prg $<
test-c64-screen-jiffydos: build/p8vi-c64.prg
	$(PYTHON) -B $(EDTEST) screen $(JIFFY) --prg $<
test-c64reu-jiffydos: build/p8vi-c64reu.prg
	$(PYTHON) -B $(EDTEST) files $(JIFFY) --prg $< --reu 512 --limit 3000000000
	$(PYTHON) -B $(EDTEST) files $(JIFFY) --prg $< --skip big
	$(PYTHON) -B $(RECTEST) $(JIFFY) --prg $<
	$(PYTHON) -B $(EDTEST) screen $(JIFFY) --prg $< --reu 512
test-c64font-jiffydos: build/p8vi-c64font.prg build/oscii.fnt
	$(PYTHON) -B $(EDTEST) files $(JIFFY) --prg $< --font build/oscii.fnt --reu 512 --limit 3000000000 $(FONT_SKIP)
	$(PYTHON) -B $(EDTEST) files $(JIFFY) --prg $< --font build/oscii.fnt --skip big $(FONT_SKIP)
	$(PYTHON) -B $(RECTEST) $(JIFFY) --prg $< --font build/oscii.fnt
	$(PYTHON) -B $(EDTEST) screen $(JIFFY) --prg $< --font build/oscii.fnt --reu 512
test-c64disk-jiffydos: build/p8vi-c64disk.prg
	$(PYTHON) -B $(EDTEST) files $(JIFFY) --prg $< --paged --limit 3000000000 --skip huge --skip bigundo
	$(PYTHON) -B $(EDTEST) screen $(JIFFY) --prg $<
test-jiffydos: test-c64-jiffydos test-c64-screen-jiffydos test-c64reu-jiffydos test-c64font-jiffydos test-c64disk-jiffydos

# REU detection and reset tests on a C64 in VICE: detection finds every size
# and leaves the REU's memory alone, and the REU keeps it over a reset
test-reu: build
	$(PCC) $(PCCARGSC64) -o build/reudetect.prg tests/reu/reudetect.p8
	$(PCC) $(PCCARGSC64) -o build/reureset.prg tests/reu/reureset.p8
	$(PYTHON) -B $(REUTEST) --build build

# the 6502 fastmem routines against plain Prog8, on a C64 in VICE
test-fastmem: build
	$(PCC) $(PCCARGSC64) -o build/fastmemtest.prg tests/fastmem/fastmemtest.p8
	cd build && x64sc -default -minimized -sounddev dummy -warp -debugcart -autostartprgmode 1 -autostart fastmemtest.prg -limitcycles 900000000 -exitscreenshot fastmemtest.png > fastmemtest.log 2>&1; grep -q 'DBGCART: exit(0)' fastmemtest.log && echo "fastmem: ok" || (echo "fastmem: FAIL, see build/fastmemtest.png"; false)

# timings of the text store routines on a C64 in VICE (page store and gap
# buffer), screenshots in build/bench-page.png and build/bench-gap.png
bench: build
	$(PCC) $(PCCARGSC64REU) -o build/storebench.prg tests/bench/storebench.p8
	cd build && x64sc -default -minimized -sounddev dummy -warp -debugcart -autostartprgmode 1 -autostart storebench.prg -limitcycles 900000000 -exitscreenshot bench-page.png >/dev/null 2>&1
	$(PCC) $(PCCARGSC64) -o build/storebench.prg tests/bench/storebench.p8
	cd build && x64sc -default -minimized -sounddev dummy -warp -debugcart -autostartprgmode 1 -autostart storebench.prg -limitcycles 900000000 -exitscreenshot bench-gap.png >/dev/null 2>&1

# the C128 in VICE's x128 (a 1541), on the 40 column and the 80 column (VDC)
# screen
test-c128: build/p8vi-c128.prg
	$(PYTHON) -B $(EDTEST) files --machine c128 -j 4 --prg $<
	$(PYTHON) -B $(EDTEST) screen --machine c128 -j 4 --prg $<
	$(PYTHON) -B $(EDTEST) files --machine c128-80 -j 4 --prg $<
	$(PYTHON) -B $(EDTEST) screen --machine c128-80 -j 4 --prg $<

# the C128 bank 1 build: also the page store's suites (--paged), except
# read-dir (no :@$ in this build) and the two that need more than bank 1
# holds (huge: about 87 KB of text; bigundo: 29 KB and its undo), and marks
# and zview (features.MARKS and Z_VIEW are off for room).  it is also a font
# build (oscii.fnt on its disks, and the font suite): it leaves out g-cmds
# and ascii as the C64 font build does
C128X_SKIP = --skip read-dir --skip huge --skip bigundo --skip marks --skip zview
C128X_FONT = --font build/oscii.fnt --skip g-cmds --skip ascii
test-c128x: build/p8vi-c128x.prg build/oscii.fnt
	$(PYTHON) -B $(EDTEST) files --machine c128 --paged --limit 3000000000 -j 4 $(C128X_SKIP) $(C128X_FONT) --prg $<
	$(PYTHON) -B $(EDTEST) screen --machine c128 -j 4 --font build/oscii.fnt --prg $<
	$(PYTHON) -B $(EDTEST) files --machine c128-80 --paged --limit 3000000000 -j 4 $(C128X_SKIP) $(C128X_FONT) --prg $<
	$(PYTHON) -B $(EDTEST) screen --machine c128-80 -j 4 --font build/oscii.fnt --prg $<
	$(PYTHON) -B $(RECTEST) --machine c128 --no-reu --font build/oscii.fnt --prg $<

# the C128 REU build: with a 512 KB REU (all the page store's suites), and
# without one (bank 1, as test-c128x); read-dir: no :@$ in this build, no
# marks or & either
C128REU_SKIP = --skip read-dir --skip prefix --skip marks --skip subst-again
test-c128reu: build/p8vi-c128reu.prg
	$(PYTHON) -B $(EDTEST) files --machine c128 --reu 512 --limit 3000000000 -j 4 $(C128REU_SKIP) --prg $<
	$(PYTHON) -B $(EDTEST) screen --machine c128 --reu 512 -j 4 --prg $<
	$(PYTHON) -B $(EDTEST) files --machine c128-80 --reu 512 --limit 3000000000 -j 4 $(C128REU_SKIP) --prg $<
	$(PYTHON) -B $(EDTEST) screen --machine c128-80 --reu 512 -j 4 --prg $<
	$(PYTHON) -B $(EDTEST) files --machine c128 --paged --limit 3000000000 -j 4 $(C128X_SKIP) --skip prefix --skip subst-again --prg $<
	$(PYTHON) -B $(RECTEST) --machine c128 --prg $<
	$(PYTHON) -B $(RECTEST) --machine c128-80 --no-reu --prg $<

# the PET in VICE's xpet (a 4032 with a 2031 drive).  left out, for the
# features it doesn't have: ascii, crlf, big, final-eol, read-format, find
# (ASCII and CR LF files), subst, subst-again, dos, read-dir
PET_SKIP = --skip ascii --skip crlf --skip big --skip final-eol --skip read-format --skip find \
	--skip subst --skip subst-again --skip dos --skip read-dir
test-pet32: build/p8vi-pet32.prg
	$(PYTHON) -B $(EDTEST) files --machine pet -j 4 --prg $< $(PET_SKIP)
	$(PYTHON) -B $(EDTEST) screen --machine pet -j 4 --prg $<

# the Plus/4 in VICE's xplus4 (a 1541)
test-plus4: build/p8vi-plus4.prg
	$(PYTHON) -B $(EDTEST) files --machine plus4 -j 4 --prg $<
	$(PYTHON) -B $(EDTEST) screen --machine plus4 -j 4 --prg $<

# the MEGA65 in xmega65 (and c1541), driven through its serial monitor by
# tools/m65harness.py: the suites of tests/vice/edtest.py and the font
# suite.  left out, as for the C64 font build: g-cmds and ascii (they type
# and keep PETSCII graphics in ways the font build maps to the ASCII
# characters)
FONT_SKIP_M65 = --skip g-cmds --skip ascii
test-mega65: build/p8vi-mega65.prg
	$(PYTHON) -B $(M65TEST) --prg $< --font $(FONT_SKIP_M65) files
	$(PYTHON) -B $(M65TEST) --prg $< screen

# the MEGA65 page store build, with the suites for more text than main RAM
# holds (--paged) and the font suite: the pages in attic RAM (xemu has it).
# left out: subst, subst-again, read-dir, prefix, marks and zview (SUBST,
# DIR, MARKS and Z_VIEW are off in this build), and g-cmds and ascii as
# above.  then some of them as on a Nexys4 board (model ID $40), without
# attic RAM: the pages in banks 4 and 5 (not bigundo: 30 KB of text, undo
# and yank need more than their 126 pages)
M65DMA_SKIP = --skip subst --skip subst-again --skip read-dir --skip prefix --skip marks --skip zview
test-mega65dma: build/p8vi-mega65dma.prg
	$(PYTHON) -B $(M65TEST) --prg $< --paged --font $(M65DMA_SKIP) $(FONT_SKIP_M65) files
	$(PYTHON) -B $(M65TEST) --prg $< --paged --model 64 files delete-put undo pages huge
	$(PYTHON) -B $(M65TEST) --prg $< screen

# which zero page bytes the MEGA65 ROM changes in KERNAL calls (for the
# zp_* lists in config/mega65.properties), in xmega65 headless.  the
# program is also on the disk as zpload, for its LOAD test.
ZPDISK = build/zpwatch.d81
test-mega65-zp: build
	$(PCC) -srcdirs "tests/mega65" -target config/mega65.properties -o build/zpwatch.prg tests/mega65/zpwatch.p8
	c1541 -format zpwatch,01 d81 $(ZPDISK)
	c1541 -attach $(ZPDISK) -write build/zpwatch.prg zpload,p
	xmega65 -headless -sleepless -besure -prg build/zpwatch.prg -prgexit \
		-8 $(abspath $(ZPDISK)) -dumpscreen build/zpwatch.txt
	cat build/zpwatch.txt
# which MEGA65 keys give which PETSCII codes (the table in tools/m65harness.py)
test-mega65-keymap: build
	$(PCC) -srcdirs "tests/mega65" -target config/mega65.properties -o build/keyecho.prg tests/mega65/keyecho.p8
	$(PYTHON) -B $(M65KEYMAP) --prg build/keyecho.prg

# the TRS-80s in trs80gp, a window per suite (tests/trs80/trstest.py; the
# test builds play the keys in KEYS/TXT first): the suites for CBM things
# are left out.  the Model 4 runs marks and zview too, the Model 4 with
# 128 KB recovery as well (tests/trs80/rectest.py)
test-trs80: build/p8vi-trs80test.cmd
	$(PYTHON) -B $(TRSTEST) -j 3
test-trs80m4: build/p8vi-trs80m4test.cmd
	$(PYTHON) -B $(TRSTEST) --model 4 -j 3
test-trs80m4x: build/p8vi-trs80m4xtest.cmd
	$(PYTHON) -B $(TRSTEST) --model 4x -j 3
	$(PYTHON) -B $(TRSRECTEST)

# the Amiga on an A500 in Copperline (tests/amiga/amigatest.py: Kickstart
# 1.3 if it's there, else AROS): edtest's file and screen suites (the screen
# from p8vi's output redirected to a file) and :set number's, new files' line
# endings, its own window (as from Workbench), and with 1.3 the window
# resized while p8vi runs (the mouse drags its size gadget)
test-amiga: build/p8vi-amigatest
	$(PYTHON) -B $(AMIGATEST)
	$(PYTHON) -B $(AMIGATEST) screen
	$(PYTHON) -B $(AMIGATEST) number
	$(PYTHON) -B $(AMIGATEST) endings
	$(PYTHON) -B $(AMIGATEST) --own-window files delete-put undo marks
	$(if $(AMIGA_ROM),$(PYTHON) -B $(AMIGATEST) --resize)

# the Color Computers in XRoar, headless (tests/coco/cocotest.py,
# tests/coco3/coco3test.py: the test builds play the keys in KEYS.TXT
# first, toolshed's decb copies the files on and off the disk images)
test-coco: build/p8vi-cocotest.bin
	$(PYTHON) -B $(COCOTEST) -j 4
test-coco3: build/p8vi-coco3test.bin
	$(PYTHON) -B $(COCO3TEST) -j 4

#
# how much room is left, and the known miscompiles
#

# the memory map of each build and the room left: p8size reads the map
# that p8c's -map writes (build/name.p8map), which knows where the
# program must end (p8size MAP for where the bytes go, A.p8map B.p8map
# to compare two).  p8vi-c64font must end below its font at $c800.  The
# Z80 and Amiga builds have no fixed end (the text gets the heap): sizes
# only (the host build gets no map).  The overlay builds have no map: p8c's -meminfo, main
# memory and each overlay
VIC20_MIN_FREE = 64
P8SIZE = p8size
size: $(PROGS)
	$(P8SIZE) --map build/p8vi-c64.p8map
	$(P8SIZE) --map --memtop 0xc800 build/p8vi-c64font.p8map
	$(P8SIZE) --map build/p8vi-c64reu.p8map
	$(P8SIZE) --map build/p8vi-c64disk.p8map
	$(P8SIZE) --map build/p8vi-cx16.p8map
	$(P8SIZE) --map build/p8vi-cx16iso.p8map
	$(PCC) $(PCCARGSCX16) -meminfo -o build/p8vi-cx16ovl.prg src/p8vi_cx16ovl.p8 | sed -n 1,3p
	$(PCC) $(PCCARGSCX16ISO) -meminfo -o build/p8vi-cx16isoovl.prg $(CX16ISO)/src/p8vi_cx16isoovl.p8 | sed -n 1,3p
	$(P8SIZE) --map build/p8vi-mega65.p8map
	$(P8SIZE) --map build/p8vi-mega65dma.p8map
	$(P8SIZE) --map build/p8vi-pet32.p8map
	$(P8SIZE) --map build/p8vi-c128.p8map
	$(P8SIZE) --map build/p8vi-c128x.p8map
	$(P8SIZE) --map build/p8vi-c128reu.p8map
	$(P8SIZE) --map build/p8vi-plus4.p8map
	$(P8SIZE) --map --min-free $(VIC20_MIN_FREE) build/p8vi-vic20.p8map
	$(P8SIZE) --map build/p8vi-trs80.p8map
	$(P8SIZE) --map build/p8vi-trs80m4.p8map
	$(P8SIZE) --map build/p8vi-trs80m4x.p8map
	$(P8SIZE) --map build/p8vi-cpm.p8map
	$(P8SIZE) --map build/p8vi-coco.p8map
	$(P8SIZE) --map build/p8vi-coco3.p8map
	$(P8SIZE) --map build/p8vi-amiga.p8map

# look in the generated assembler for the silent miscompiles found so far
# (bugs/uword_array_eq_ubyte.p8, bugs/min_ubyte_expressions.p8)
audit: $(PROGS)
	$(PYTHON) $(ASMAUDIT) build/p8vi-c64.asm build/p8vi-c64reu.asm build/p8vi-c64font.asm build/p8vi-cx16.asm build/p8vi-vic20.asm

.PHONY: all build clean release disk font c64 cx16 trs80 trs80m4 trs80m4x cpm coco host amiga x16-dir frehd-dir amiga-dir quick test-all $(TESTS)

#
# end-of-file
#
