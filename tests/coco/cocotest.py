#!/usr/bin/env python3
"""The editor's file tests on a Tandy Color Computer 2 with 64 KB and Disk
BASIC, in XRoar.

    cocotest.py [--prg build/p8vi-cocotest.bin] [-j N] [--skip SUITE] [name...]

Runs tests/vice/edtest.py's file suites with the Color Computer test build
(features.KEYFILE), which plays the keys in KEYS.TXT before it reads the
keyboard.  For each suite, in a directory of its own:

  - a disk image (toolshed's decb) gets T.TXT, the text, and KEYS.TXT:
    ":e t.txt", the suite's keys and ":q!" as the editor's key codes
  - XRoar runs the program without a window, as fast as the host can, for
    SECONDS of the machine's time (p8vi has quit to BASIC long before), and
    writes the disk image back
  - decb copies each file the suite checks off the disk, and it is compared
    with the suite's (CR as LF)

XRoar is XROAR (its path), else "xroar" on the PATH; it needs the Color
Computer 2's and Disk BASIC's ROMs.
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
EDITOR = os.environ.get('P8VI', os.path.join(HERE, '..', '..'))
sys.path.insert(0, os.path.join(EDITOR, 'tests', 'vice'))
sys.path.insert(0, os.path.join(EDITOR, 'tests', 'trs80'))
import edtest  # noqa: E402
import trstest  # noqa: E402  (the same text rules: typed letters stay as they are)

XROAR = os.environ.get('XROAR') or 'xroar'
SECONDS = 240
TIMEOUT = 300
# the test build's key buffer (KEY_BUF_SIZE in src/coco/platform.p8)
KEY_BUF_SIZE = 256
# what the build leaves out (features.MARKS, Z_VIEW)
NO_ROOM = ['marks', 'zview']


def coco_name(name):
    """a test's file name as Disk BASIC has it: t.txt is T.TXT"""
    return name.upper()


def run_suite(args, suite):
    name, keys, expected, *text = suite
    work = tempfile.mkdtemp(prefix='coco-' + name + '-', dir=args.work)
    disk = os.path.join(work, 't.dsk')
    start = text[0] if text else edtest.SHORT
    swap = trstest.to_trs if not trstest.looks_ascii(start) else (lambda t: t)
    with open(os.path.join(work, 't.txt'), 'wb') as f:
        # (LF line endings to CR, CR LF stays CR LF)
        f.write(swap(start).replace(b'\r\n', b'\0').replace(b'\n', b'\r').replace(b'\0', b'\r\n'))
    played = trstest.key_bytes(':e t.txt\\n' + keys + ':q!\\n')
    if len(played) > KEY_BUF_SIZE:
        return name, False, [f'  {len(played)} bytes of keys, the test build holds {KEY_BUF_SIZE}']
    with open(os.path.join(work, 'keys.txt'), 'wb') as f:
        f.write(played)
    quiet = dict(stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(['decb', 'dskini', disk], **quiet)
    for host, there in (('t.txt', 'T.TXT'), ('keys.txt', 'KEYS.TXT')):
        subprocess.run(['decb', 'copy', '-1', '-a', os.path.join(work, host), disk + ',' + there], **quiet)
    command = [XROAR, '-q', '-ui', 'null', '-ao', 'null', '-no-ratelimit', '-machine', 'coco2bus', '-ram', '64',
               '-load-fd0', disk, '-run', args.prg, '-timeout', str(SECONDS)]
    lines = []
    try:
        subprocess.run(command, cwd=work, timeout=TIMEOUT, **quiet)
    except subprocess.TimeoutExpired:
        lines.append(f'  XRoar did not finish in {TIMEOUT} s (see {work})')
    for fname, want in expected:
        path = os.path.join(work, fname + '.out')
        subprocess.run(['decb', 'copy', disk + ',' + coco_name(fname), path], **quiet)
        got = None
        if os.path.exists(path):
            with open(path, 'rb') as f:
                got = trstest.lf_endings(f.read())
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


def main():
    ap = argparse.ArgumentParser(description='p8vi file tests on a Color Computer 2 in XRoar')
    ap.add_argument('names', nargs='*', help='only run these suites')
    ap.add_argument('--prg', default='build/p8vi-cocotest.bin', help='the test build')
    ap.add_argument('--work', default='build')
    ap.add_argument('-j', type=int, default=1)
    ap.add_argument('--skip', action='append', default=[], metavar='SUITE')
    args = ap.parse_args()
    args.prg = os.path.abspath(args.prg)
    args.work = os.path.abspath(args.work)
    suites = [s for s in edtest.FILE_SUITES
              if (not args.names or s[0] in args.names) and s[0] not in args.skip
              and (args.names or s[0] not in trstest.CBM_ONLY + NO_ROOM)]
    if not suites:
        sys.exit('no such suite')
    failed = 0
    with ThreadPoolExecutor(max_workers=args.j) as pool:
        for name, ok, lines in pool.map(lambda s: run_suite(args, s), suites):
            print(f'{name}: {"ok" if ok else "FAIL"}', flush=True)
            for line in lines:
                print(line)
            failed += not ok
    print(f'files: {len(suites) - failed} of {len(suites)} passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
