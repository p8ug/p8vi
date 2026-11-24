# p8c, trs80m4: diskio.rename fails for a file on drive 0

**Status:** open (2026-11-23).  Found by p8vi's `make test-all` with p8c:
`test-trs80m4x`'s recovery tests (tests/trs80/rectest.py) save nothing.

## What happens

A program built with `p8c -target trs80m4` writes `p8vi.tmp` and renames it
to `r.txt`, as p8vi's safe save does.  Run under LS-DOS 6.3 in trs80gp with
drive 0 (the system disk) writable, the new file goes to drive 0: the
write works (`status_code()` 0), the rename fails (`status_code()` 255) and
there is no `R/TXT`.  With drive 0 write-protected the file goes to drive
1 and the rename works.  The same source built with prog8c-llvm (`-target
llvm16 -triple z80-trs80-m4`) works either way.

| built with | drive 0 | R/TXT | the program says |
|---|---|---|---|
| p8c | writable | none | written 0 renamed 255 |
| p8c | write-protected | hello | written 0 renamed 0 |
| prog8c-llvm | writable | hello | written 0 renamed 0 |
| prog8c-llvm | write-protected | hello | written 0 renamed 0 |

In p8vi the same: `:w` of a new file on a writable drive 0 (p8vi.tmp, then
the rename) leaves no file; both the plain Model 4 build and the 128 KB
one.  p8vi's file suites pass because tests/trs80/trstest.py write-protects
drive 0 (`-im wp 0 on`); rectest.py doesn't.

## Repro

`bugs/p8c_trs80m4_rename_drive0.p8`:

```
p8c -target trs80m4 -o wr-p8c.cmd bugs/p8c_trs80m4_rename_drive0.p8
```

then in trs80gp (Model 4, LS-DOS 6.3, its utility disk with IMPORT2 and
EXPORT2 in drive 1, a FreHD directory `dir` holding wr.cmd):

```
trs80gp -ee -batch -turbo -m4 -ld -d1 :lu4 -frehd -frehd_dir dir -itime 0 \
    -iw Ready -id 60 -i 'IMPORT2 wr.cmd WR/CMD:1\r' -id 900 \
    -i 'WR\r' -id 900 -iw Ready -id 60 \
    -i 'EXPORT2 R/TXT r.out\r' -id 600 -it -ix
```

`dir/r.out` is missing (prog8c-llvm's build: `hello\r`), and the screen
dump `dir/trs80-text-0.bin` shows `written 0 renamed 255`.  Add
`-im wp 0 on` before `-m4` and it works.

## Where to look

p8c's trs80m4 `diskio.rename` (its library, not prog8c-llvm's llvm16 one):
perhaps the drive the DOS found the file on (the new file is on drive 0
here, LS-DOS's search picks the first writable drive) isn't passed to the
rename, or a `:0` drive spec is handled differently from `:1`.
