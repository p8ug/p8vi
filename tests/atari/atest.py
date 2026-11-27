#!/usr/bin/env python3
"""The editor's tests for the Atari 8-bit version, in atari800.

    atest.py [files|screen|number] [--xe] [--machine xl|xe] [--prg PROGRAM] [-j N] [--skip SUITE] [name...]

Runs tests/vice/edtest.py's suites with the Atari test build (make
atari-test: features.KEYFILE), which plays the keys in the file KEYS before
it reads the keyboard: p8vi-ataritest.xex, or with --xe p8vi-atarixetest.xex
(the 130XE build: the text in the extra 64 KB, the page store; edtest's
REU_SUITES too, not huge or bigundo, more than 62 pages; no marks, zview or
number suites: the build leaves those out), on a 130XE.  --machine xl
runs on an 800XL instead (64 KB).  For each suite, in a directory of its
own:

  - KEYS gets ":e t.txt", the suite's keys and ":q!" as the editor's key
    codes (edtest's: \\n RETURN, \\x1b Escape, ...), T.TXT the text, its
    lines ending with ATASCII's $9b (CR LF stays CR LF)
  - atari800 (an 800XL without BASIC, -turbo, no window) runs the program
    with its host device as D: (-Hdevicename D, -H1 the directory,
    -hreadwrite): the files p8vi opens, D1:NAME, are the directory's.  It
    starts in atari800's monitor, which is given a breakpoint at sys.exit
    (from the .p8map), cont, and quit when it gets there.
  - the files left are compared with the suite's ($9b, CR LF and CR as LF)
  - (screen) the key $ff has the test build write the screen's memory to
    SCREEN1, the next $ff to SCREEN2: the screen after the suite's keys
    must be the same as after a full redraw (Ctrl-L)
  - (number) the screen suites again with :set number first, and
    tests/cpm/cpmtest.py's NUMBER_SUITES

atari800 is ATARI800 (the path), else on the PATH; without it the tests are
skipped (exit status 0).  Its ROMs are the ones its configuration file
names (~/.atari800.cfg).
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'vice'))
sys.path.insert(0, os.path.join(HERE, '..', 'trs80'))
sys.path.insert(0, os.path.join(HERE, '..', 'cpm'))
import edtest  # noqa: E402
import trstest  # noqa: E402  (the key file, the case swap, the line endings)
import cpmtest  # noqa: E402  (NUMBER_SUITES)

ATARI800 = os.environ.get('ATARI800') or shutil.which('atari800')
TIMEOUT = 120
# the test build's key buffer (KEY_BUF_SIZE in src/atari/platform.p8)
KEY_BUF_SIZE = 256


def exit_address(prg):
    """sys.exit's address, from the .p8map beside the program"""
    with open(os.path.splitext(prg)[0] + '.p8map') as f:
        for line in f:
            w = line.split()
            if w[:1] == ['code'] and w[3:] == ['sys', 'exit']:
                return w[1]
    sys.exit(f'no sys.exit in the map of {prg}')


def atascii(text):
    """a text with ATASCII's line ends: LF and CR to $9b, CR LF kept"""
    return text.replace(b'\r\n', b'\0').replace(b'\n', b'\x9b').replace(b'\r', b'\x9b').replace(b'\0', b'\r\n')


def lf_endings(text):
    """$9b, CR LF and CR as LF"""
    return trstest.lf_endings(text.replace(b'\x9b', b'\n'))


def dos_file(work, name):
    """the file of that name in the directory (the host device makes capitals)"""
    for f in os.listdir(work):
        if f.lower() == name.lower():
            return os.path.join(work, f)
    return None


def setup(args, prefix, text, keys):
    """a directory with the text and the keys: (work, problem)"""
    work = tempfile.mkdtemp(prefix=prefix, dir=args.work)
    with open(os.path.join(work, 'T.TXT'), 'wb') as f:
        f.write(atascii(text))
    played = trstest.key_bytes(':e t.txt\\n' + keys + ':q!\\n')
    if len(played) > KEY_BUF_SIZE:
        return work, f'  {len(played)} bytes of keys, the test build holds {KEY_BUF_SIZE}'
    with open(os.path.join(work, 'KEYS'), 'wb') as f:
        f.write(played)
    return work, ''


def atari800(args, work):
    """run p8vi until sys.exit: '' or what went wrong"""
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy')
    command = [ATARI800, '-' + args.machine, '-nobasic', '-turbo', '-nosound', '-hreadwrite', '-Hdevicename', 'D',
               '-H1', work, '-monitor', '-run', args.prg]
    monitor = f'bpc {args.exit}\ncont\nquit\n'.encode()
    try:
        r = subprocess.run(command, cwd=work, input=monitor, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, env=env, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return f'  atari800 did not finish in {TIMEOUT} s (see {work})'
    out = r.stdout.decode(errors='replace')
    with open(os.path.join(work, 'atari800.log'), 'w') as f:
        f.write(out)
    if f'(breakpoint at {args.exit.upper()})' not in out:
        return f'  p8vi did not get to its end (see {work}/atari800.log)'
    return ''


def run_files(args, suite):
    name, keys, expected, *text = suite
    start = text[0] if text else edtest.SHORT
    swap = trstest.to_trs if not trstest.looks_ascii(start) else (lambda t: t)
    work, problem = setup(args, 'at-' + name + '-', swap(start), keys)
    if not problem:
        problem = atari800(args, work)
    lines = [problem] if problem else []
    for fname, want in expected:
        path = dos_file(work, fname)
        got = None
        if path:
            with open(path, 'rb') as f:
                got = lf_endings(f.read())
        if want is not None:
            want = trstest.lf_endings(want)
            want = trstest.to_trs(want) if (name, fname) in trstest.NEW_TEXTS else swap(want)
        if got != want:
            lines += [f'  {fname}: FAIL', f'    want {want!r}', f'    got  {got!r}']
    if lines:
        lines.append(f'  (files in {work})')
    else:
        shutil.rmtree(work)
    return name, not lines, lines


def rows(path):
    """a SCREENn's 24 rows of 40 screen codes, as text (inverse shows as
    the character: the cursor's place)"""
    with open(path, 'rb') as f:
        d = f.read()
    out = []
    for r in range(24):
        row = ''
        for c in d[r * 40:r * 40 + 40]:
            c &= 0x7f
            row += chr(c + 0x20) if c < 0x40 else chr(c - 0x40) if c < 0x60 else chr(c)
        out.append(row)
    return out


def run_screen(args, suite):
    name, text, keys = suite
    work, problem = setup(args, 'ats-' + name + '-', trstest.to_trs(text), keys + r'\xff\x0c\xff')
    if not problem:
        problem = atari800(args, work)
    lines = [problem] if problem else []
    got, want = (dos_file(work, f'screen{n}') for n in (1, 2))
    if not lines and not (got and want):
        lines.append('  the keys did not get to the end')
    if not lines:
        got, want = rows(got), rows(want)
        if not ''.join(want).strip():
            lines.append('  the screen is empty')
        diff = [r for r in range(24) if got[r] != want[r]]
        if diff:
            lines.append(f'  differs from the redrawn screen in rows {diff[:8]}')
            for r in diff[:3]:
                lines += [f'    {r:2} want {want[r]!r}', f'    {r:2} got  {got[r]!r}']
    if lines:
        lines.append(f'  (files in {work})')
    else:
        shutil.rmtree(work)
    return name, not lines, lines


def run_number(args, suite):
    name, text, keys = suite
    return run_screen(args, (name, text, r':set number\n' + keys))


def main():
    ap = argparse.ArgumentParser(description='p8vi tests on an Atari 800XL in atari800')
    ap.add_argument('kind', nargs='?', default='files', choices=['files', 'screen', 'number'])
    ap.add_argument('names', nargs='*', help='only run these suites')
    ap.add_argument('--xe', action='store_true', help='the 130XE build (p8vi-atarixetest.xex)')
    ap.add_argument('--machine', choices=['xl', 'xe'], help="atari800's machine (xe with --xe, else xl)")
    ap.add_argument('--prg', help='the test build')
    ap.add_argument('--work', default='build')
    ap.add_argument('-j', type=int, default=6)
    ap.add_argument('--skip', action='append', default=[], metavar='SUITE')
    args = ap.parse_args()
    if not ATARI800:
        print('atari800 not found (set ATARI800 to its path): the Atari tests are skipped')
        sys.exit(0)
    args.prg = os.path.abspath(args.prg or ('build/p8vi-atarixetest.xex' if args.xe else 'build/p8vi-ataritest.xex'))
    args.machine = args.machine or ('xe' if args.xe else 'xl')
    no_room = ['marks', 'zview', 'huge', 'bigundo'] if args.xe else []
    if args.xe and args.kind == 'number':
        sys.exit('number is not for the 130XE build: it has no :set number')
    args.work = os.path.abspath(args.work)
    args.exit = exit_address(args.prg)
    wanted = lambda s: (not args.names or s[0] in args.names) and s[0] not in args.skip
    if args.kind == 'files':
        suites = [s for s in edtest.FILE_SUITES + (edtest.REU_SUITES if args.xe else [])
                  if wanted(s) and (args.names or s[0] not in trstest.CBM_ONLY + no_room)]
        # (D1: is the host device's directory)
        suites = trstest.with_prefix(suites, 'd1:', wanted)
        run = run_files
    elif args.kind == 'screen':
        suites = [s for s in edtest.SCREEN_SUITES if wanted(s)]
        run = run_screen
    else:
        suites = [s for s in edtest.SCREEN_SUITES + cpmtest.NUMBER_SUITES if wanted(s)]
        run = run_number
    if not suites:
        sys.exit('no such suite')
    failed = 0
    with ThreadPoolExecutor(max_workers=args.j) as pool:
        for name, ok, lines in pool.map(lambda s: run(args, s), suites):
            print(f'{name}: {"ok" if ok else "FAIL"}', flush=True)
            for line in lines:
                print(line)
            failed += not ok
    print(f'Atari{" 130XE" if args.xe else ""} {args.kind}: {len(suites) - failed} of {len(suites)} passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
