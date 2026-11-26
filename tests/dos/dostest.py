#!/usr/bin/env python3
"""The editor's file tests for the MS-DOS version, in DOSBox-X.

    dostest.py [files|screen|number] [--prg build/p8vi-dostest.exe] [-j N] [--skip SUITE] [name...]

Runs tests/vice/edtest.py's suites with the DOS test build (make
dos-test: features.KEYFILE), which plays the keys in KEYS.TXT before it
reads the keyboard.  For each suite, in a directory of its own:

  - keys.txt gets ":e t.txt", the suite's keys and ":q!" as the editor's
    key codes (edtest's: \\n RETURN, \\x1b Escape, ...), t.txt the text
  - DOSBox-X runs without a window (-silent), with the directory as drive
    C:, runs P8VI and exits
  - the files left are compared with the suite's (CR LF and CR as LF; a
    file ends at its first ^Z)
  - (screen) the key $ff has the test build write the screen's characters
    to SCREEN1.BIN, the next $ff to SCREEN2.BIN: the screen after the
    suite's keys must be the same as after a full redraw (Ctrl-L)
  - (number) the screen suites again with :set number first, and
    tests/cpm/cpmtest.py's NUMBER_SUITES

DOSBox-X is DOSBOX (the path), else dosbox-x on the PATH.
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
import edtest  # noqa: E402
import trstest  # noqa: E402  (the key file, the case swap, the line endings)
sys.path.insert(0, os.path.join(HERE, '..', 'cpm'))
import cpmtest  # noqa: E402  (NUMBER_SUITES)

DOSBOX = os.environ.get('DOSBOX') or shutil.which('dosbox-x')
TIMEOUT = 120
# the test build's key buffer (KEY_BUF_SIZE in src/dos/platform.p8)
KEY_BUF_SIZE = 256
# (DOSMACHINE=hercules: DOSBox-X's machine, for the MDA's video RAM at $b000)
MACHINE = ['-set', 'dosbox machine=' + os.environ['DOSMACHINE']] if os.environ.get('DOSMACHINE') else []


def dosbox(work):
    """run p8vi.exe in work (drive C:) and exit; '' or what went wrong"""
    command = [DOSBOX, '-silent', '-fastlaunch', '-defaultconf', '-time-limit', str(TIMEOUT),
               '-set', 'cpu cycles=max', *MACHINE, '-c', f'mount c "{work}"', '-c', 'c:', '-c', 'p8vi', '-c', 'exit']
    try:
        subprocess.run(command, cwd=work, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=TIMEOUT + 30)
    except subprocess.TimeoutExpired:
        return f'  DOSBox-X did not finish in {TIMEOUT + 30} s (see {work})'
    return ''


def dos_file(work, name):
    """the file DOS made of name (DOSBox-X gives new files upper case names)"""
    for f in os.listdir(work):
        if f.lower() == name.lower():
            return os.path.join(work, f)
    return None


def setup(args, prefix, text, keys):
    """a directory with p8vi, t.txt and the keys: (work, problem)"""
    work = tempfile.mkdtemp(prefix=prefix, dir=args.work)
    shutil.copyfile(args.prg, os.path.join(work, 'P8VI.EXE'))
    with open(os.path.join(work, 'T.TXT'), 'wb') as f:
        # (LF line endings to CR, CR LF stays CR LF)
        f.write(text.replace(b'\r\n', b'\0').replace(b'\n', b'\r').replace(b'\0', b'\r\n'))
    played = trstest.key_bytes(':e t.txt\\n' + keys + ':q!\\n')
    if len(played) > KEY_BUF_SIZE:
        return work, f'  {len(played)} bytes of keys, the test build holds {KEY_BUF_SIZE}'
    with open(os.path.join(work, 'KEYS.TXT'), 'wb') as f:
        f.write(played)
    return work, ''


def run_files(args, suite):
    name, keys, expected, *text = suite
    start = text[0] if text else edtest.SHORT
    swap = trstest.to_trs if not trstest.looks_ascii(start) else (lambda t: t)
    work, problem = setup(args, 'dos-' + name + '-', swap(start), keys)
    if not problem:
        problem = dosbox(work)
    lines = [problem] if problem else []
    for fname, want in expected:
        path = dos_file(work, fname)
        got = None
        if path:
            with open(path, 'rb') as f:
                got = trstest.lf_endings(f.read().split(b'\x1a')[0])
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
    """a SCREENn.BIN's 25 rows"""
    with open(path, 'rb') as f:
        d = f.read()
    return [d[r * 80:r * 80 + 80].decode('cp437') for r in range(25)]


def run_screen(args, suite):
    name, text, keys = suite
    work, problem = setup(args, 'doss-' + name + '-', trstest.to_trs(text), keys + r'\xff\x0c\xff')
    if not problem:
        problem = dosbox(work)
    lines = [problem] if problem else []
    got, want = (dos_file(work, f'screen{n}.bin') for n in (1, 2))
    if not lines and not (got and want):
        lines.append('  the keys did not get to the end')
    if not lines:
        got, want = rows(got), rows(want)
        if not ''.join(want).strip():
            lines.append('  the screen is empty (not the video RAM that p8vi wrote?)')
        diff = [r for r in range(25) if got[r] != want[r]]
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
    ap = argparse.ArgumentParser(description='p8vi file tests on MS-DOS in DOSBox-X')
    ap.add_argument('kind', nargs='?', default='files', choices=['files', 'screen', 'number'])
    ap.add_argument('names', nargs='*', help='only run these suites')
    ap.add_argument('--prg', default='build/p8vi-dostest.exe', help='the test build')
    ap.add_argument('--work', default='build')
    ap.add_argument('-j', type=int, default=4)
    ap.add_argument('--skip', action='append', default=[], metavar='SUITE')
    args = ap.parse_args()
    if not DOSBOX:
        print('dosbox-x not found (set DOSBOX to its path): the DOS tests are skipped')
        sys.exit(0)
    args.prg = os.path.abspath(args.prg)
    args.work = os.path.abspath(args.work)
    wanted = lambda s: (not args.names or s[0] in args.names) and s[0] not in args.skip
    if args.kind == 'files':
        suites = [s for s in edtest.FILE_SUITES if wanted(s) and (args.names or s[0] not in trstest.CBM_ONLY)]
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
    print(f'{args.kind}: {len(suites) - failed} of {len(suites)} passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
