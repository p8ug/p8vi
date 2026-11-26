# p8c, appleii: writing a file leaks about 15 sectors each time

**Status:** fixed in p8p8 0.6.1-dev (2026-11-26).  fm_call took the code
in the parameters for an error when the carry was clear: an OPEN that
creates the file leaves 6 (file not found) there with the file open, and
f_open_w opened it again, which lost DOS's note of the track it had
reserved, so CLOSE had nothing to give back.  Now fm_call returns 0
unless the carry is set, and the second open is gone.  The "hang" was
bobbin's --max-runtime (a write takes about 30 emulated seconds); a full
disk gives error 9.  The return to BASIC: DOS keeps its caller's stack
pointer in one byte that COUT overwrites; the startup saves it and the
exit puts it back (when DOS 3.3 is at $3d0).  Checked with p8vi: the
repro's 8 writes leave 270 of 272 free sectors (the file's 2), p8vi's
DOS 3.3 suites pass on the system master as it is, and after :q! the
BASIC prompt runs PRINT and CATALOG.

Found while porting p8vi to the Apple II (DOS 3.3): its file suites hung
at about the 7th `:w`.

## What happens

DOS 3.3 gives a file a whole track (16 sectors) when it needs room, and its
CLOSE frees the sectors the file didn't use.  After a program built with
`p8c -target appleii` writes a file with `diskio.f_open_w`, `f_write` and
`f_close_w`, those sectors stay marked used in the VTOC: a T file of 2
sectors (its track/sector list and one of data) takes 17 off the free
count, and writing it again (f_open_w deletes it first) takes another 15.

| writes of PROBE ("x\n", a T file) | free sectors (a copy of the DOS 3.3 system master with the program) |
|---|---|
| 0 | 272 |
| 1 | 255 |
| 2 | 240 |
| 8 | 188 |

The catalog says `T 002 PROBE` throughout.  When the free sectors run out
the next `f_open_w` or `f_write` doesn't come back (the repro stops at the
15th write; p8vi, whose safe save writes p8vi.tmp, deletes and renames,
at its 7th to 10th save on the master disk).  Ten writes of ten different
new files, one each, work: it's the free sectors, not the catalog.

DOS's own commands don't leak: an Applesoft loop of `DELETE PROBE`,
`OPEN PROBE`, `WRITE PROBE`, `PRINT "X"`, `CLOSE PROBE` eight times (with
Ctrl-D, on a fresh copy of the master) leaves 281 of its 283 free sectors,
the file's 2.  So it looks like the file manager
CLOSE that f_close_w makes doesn't get to free them: perhaps the work area
(the 45 bytes at write_memory) or the VTOC buffer isn't what CLOSE expects,
or prepare() sets something for CLOSE that it shouldn't (it sets RANGE and
the record/byte fields for every call).

## Repro

`bugs/p8c_appleii_close_w_leaks_sectors.p8`, on a copy of the DOS 3.3
system master in bobbin (the first line typed during the boot can get
lost, hence the PRINT):

```
p8c -target appleii -o leak.bin bugs/p8c_appleii_close_w_leaks_sectors.p8
cp "Apple DOS 3.3 January 1983.dsk" m.dsk
dos33 -y m.dsk SAVE B leak.bin LEAK
printf 'PRINT 1+1\rBRUN LEAK\r' | bobbin --simple --turbo --disk m.dsk --max-runtime 900
```

It prints `1 w 2 w ... 14 w 15` and hangs there.  With `for i in 1 to 8`
the program ends, and the VTOC (track 17 sector 0, the bitmaps from $38)
has 84 fewer free sectors than before, for one 2-sector file.

## Also seen (not looked into yet)

After a program that printed anything with `txt.print` or `cbm.CHROUT`
returns (BRUN from the BASIC prompt), the next lines typed in bobbin
(`PRINT 3`) aren't run; after a program with an empty `start()` they are.
That may be bobbin's line-oriented input, or DOS's output hook state:
not tried on another emulator or a real machine.  (`printf 'PRINT
1+1\rBRUN PROG\rPRINT 3\r' | bobbin --simple --turbo --disk e.dsk`)
