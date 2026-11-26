#!/usr/bin/env python3
"""The editor's tests for the Apple II versions, DOS 3.3 and ProDOS, in bobbin.

    a2test.py [files|screen|number] [--prodos|--prodosx] [--ram KB] [--prg PROGRAM] [--disk DISK] [-j N] [--skip SUITE] [name...]

Runs tests/vice/edtest.py's suites with an Apple II test build
(features.KEYFILE), which plays the keys in the file KEYS before it reads
the keyboard: p8vi-appleiitest.bin (DOS 3.3), with --prodos
p8vi-prodostest.sys, with --prodosx p8vi-prodosxtest.sys (128 KB: the text
in aux memory, the page store; edtest's REU_SUITES too).  --ram 64 gives
bobbin's //e 64 KB, no aux memory.  For each suite, in a directory of its
own:

  - a copy of a disk that boots the DOS (--disk; DOS 3.3: A2_DISK, such as
    the system master; ProDOS:
    PRODOS_DISK, such as bobbin's images/prodos242.dsk, which starts
    BASIC.SYSTEM) gets the program, KEYS (":e t.txt", the suite's keys and
    ":q!" as the editor's key codes) and T.TXT (the text, CR line endings).
    DOS 3.3 with dos33 (dos33fsprogs): P8VI and KEYS as B files (p8c's .bin
    has BSAVE's address and length before it, KEYS gets them), T.TXT as a
    T file (bit 7 set, a 0 at the end).  ProDOS with AppleCommander's ac
    (AC_JAR, the jar): P8VI.SYSTEM as SYS for $2000, KEYS as BIN, T.TXT as
    TXT, as they are.
  - bobbin (--simple, --turbo) boots it and is typed PRINT 1+1 (the first
    line typed during the boot can get lost) and BRUN P8VI, or -P8VI.SYSTEM;
    it stops at the program's sys.exit (--trap-success, its address from
    the .p8map).  The test build waits two seconds before it ends, so that
    the drive's motor has stopped: bobbin writes the disk image back then.
  - the files left are read back and compared with the suite's (DOS 3.3:
    bit 7 cleared, up to the first 0; CR LF and CR as LF)
  - (screen) the key $ff has the test build write the screen's memory to
    SCREEN1, the next $ff to SCREEN2: the screen after the suite's keys
    must be the same as after a full redraw (Ctrl-L)
  - (number, ProDOS: the build with features.NUMBER) the screen suites
    with :set number first, and tests/cpm/cpmtest.py's NUMBER_SUITES

bobbin is BOBBIN (the path), else on the PATH, and dos33 likewise (DOS33).
Without them, java and AC_JAR (ProDOS), or the disk, the tests are skipped
(exit status 0).
"""

import argparse
import glob
import os
import shutil
import struct
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

BOBBIN = os.environ.get('BOBBIN') or shutil.which('bobbin')
DOS33 = os.environ.get('DOS33') or shutil.which('dos33')
JAVA = shutil.which('java')
TIMEOUT = 300
# the emulated seconds bobbin may run (with --turbo the boot alone takes
# more than a minute of them, and a save under DOS 3.3 about 30: edits
# saves ten times)
EMULATED = 3000
# the test build's key buffer (KEY_BUF_SIZE in src/appleii/platform.p8)
KEY_BUF_SIZE = 256


def run(command):
    return subprocess.run(command, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)


class Dos33:
    """DOS 3.3 (p8vi-appleii): dos33fsprogs' dos33"""
    name = 'DOS 3.3'
    program = 'P8VI'
    command = b'BRUN P8VI'
    # the screen files are B files: BSAVE's four bytes first
    screen_skip = 4
    # what the build leaves out for room (src/p8vi_appleii.p8's features:
    # SUBST, MARKS); and big, whose :r makes 6 KB
    no_room = ['subst', 'subst-again', 'marks', 'big']

    def tools(self, args):
        return [('dos33', DOS33)]

    def dos33(self, disk, *a):
        return run([DOS33, '-y', disk] + list(a))

    def prepare(self, disk):
        # (the disk as it is: the system master boots, loads Integer BASIC
        # and has about 170 sectors free after P8VI, plenty since p8c's
        # diskio no longer leaks the rest of a file's track,
        # bugs/p8c_appleii_close_w_leaks_sectors.md)
        pass

    def put(self, work, disk, name, kind, data):
        """kind: 'program', 'keys' or 'text'"""
        if kind == 'program':
            path = data
            dtype = 'B'
        else:
            path = os.path.join(work, name.lower())
            if kind == 'keys':
                data = struct.pack('<HH', 0x4000, len(data)) + data
                dtype = 'B'
            else:
                data = bytes(c | 0x80 for c in data) + b'\0'
                dtype = 'T'
            with open(path, 'wb') as f:
                f.write(data)
        r = self.dos33(disk, 'SAVE', dtype, path, name)
        return '' if r.returncode == 0 else f'dos33 SAVE {name}: {r.stdout.decode(errors="replace").strip()}'

    def get(self, work, disk, name):
        out = os.path.join(work, name.upper() + '.out')
        self.dos33(disk, 'LOAD', name.upper(), out)
        if not os.path.exists(out):
            return None
        with open(out, 'rb') as f:
            return f.read()

    def text(self, data):
        return bytes(c & 0x7f for c in data).split(b'\0')[0]


class Prodos:
    """ProDOS (p8vi-prodos): AppleCommander's ac (a jar, run with java)"""
    name = 'ProDOS'
    program = 'P8VI.SYSTEM'
    command = b'-P8VI.SYSTEM'
    screen_skip = 0
    no_room = []

    def __init__(self, jar):
        self.jar = jar

    def tools(self, args):
        return [('java', JAVA), ('AppleCommander (AC_JAR)', self.jar)]

    def ac(self, *a, data=None):
        return subprocess.run([JAVA, '-jar', self.jar] + list(a), input=data,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE)

    def prepare(self, disk):
        pass

    def put(self, work, disk, name, kind, data):
        if kind == 'program':
            with open(data, 'rb') as f:
                data = f.read()
            a = ['-p', disk, name, 'SYS', '0x2000']
        elif kind == 'keys':
            a = ['-p', disk, name, 'BIN', '0x4000']
        else:
            a = ['-p', disk, name, 'TXT']
        r = self.ac(*a, data=data)
        return '' if r.returncode == 0 else f'ac -p {name}: {(r.stdout + r.stderr).decode(errors="replace").strip()}'

    def get(self, work, disk, name):
        # (a file that isn't there: "NAME: No match." and status 0)
        r = self.ac('-g', disk, name.upper())
        if r.returncode != 0 or b'No match' in r.stdout + r.stderr:
            return None
        return r.stdout

    def text(self, data):
        return data


def exit_address(prg):
    """sys.exit's address, from the .p8map beside the program"""
    with open(os.path.splitext(prg)[0] + '.p8map') as f:
        for line in f:
            w = line.split()
            if w[:1] == ['code'] and w[3:] == ['sys', 'exit']:
                return w[1]
    sys.exit(f'no sys.exit in the map of {prg}')


def setup(args, prefix, text, keys):
    """a directory with the disk: (work, disk, problem)"""
    work = tempfile.mkdtemp(prefix=prefix, dir=args.work)
    disk = os.path.join(work, 'p8vi.dsk')
    shutil.copyfile(args.disk, disk)
    args.dos.prepare(disk)
    played = trstest.key_bytes(':e t.txt\\n' + keys + ':q!\\n')
    if len(played) > KEY_BUF_SIZE:
        return work, disk, f'  {len(played)} bytes of keys, the test build holds {KEY_BUF_SIZE}'
    text = text.replace(b'\r\n', b'\0').replace(b'\n', b'\r').replace(b'\0', b'\r\n')
    for name, kind, data in ((args.dos.program, 'program', args.prg), ('KEYS', 'keys', played),
                             ('T.TXT', 'text', text)):
        problem = args.dos.put(work, disk, name, kind, data)
        if problem:
            return work, disk, '  ' + problem
    return work, disk, ''


def bobbin(args, work, disk):
    """boot the disk, start p8vi, until sys.exit: '' or what went wrong"""
    command = [BOBBIN, '--simple', '--turbo', '--disk', disk, '--max-runtime', str(EMULATED),
               '--trap-success', args.exit] + (['--ram', str(args.ram)] if args.ram else [])
    try:
        r = subprocess.run(command, cwd=work, input=b'PRINT 1+1\r' + args.dos.command + b'\r',
                           stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return f'  bobbin did not finish in {TIMEOUT} s (see {work})'
    out = r.stdout.decode(errors='replace')
    with open(os.path.join(work, 'bobbin.log'), 'w') as f:
        f.write(out)
    if 'REPORT SUCCESS' not in out:
        return f'  p8vi did not get to its end (see {work}/bobbin.log)'
    return ''


def run_files(args, suite):
    name, keys, expected, *text = suite
    start = text[0] if text else edtest.SHORT
    swap = trstest.to_trs if not trstest.looks_ascii(start) else (lambda t: t)
    work, disk, problem = setup(args, 'a2-' + name + '-', swap(start), keys)
    if not problem:
        problem = bobbin(args, work, disk)
    lines = [problem] if problem else []
    for fname, want in expected:
        got = args.dos.get(work, disk, fname)
        if got is not None:
            got = trstest.lf_endings(args.dos.text(got))
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


def rows(args, data):
    """a SCREENn's 24 rows of 40, as text (inverse as lower case is not
    told apart: the cursor's place shows as the character)"""
    data = data[args.dos.screen_skip:args.dos.screen_skip + 960]
    out = []
    for r in range(24):
        row = bytearray()
        for c in data[r * 40:r * 40 + 40]:
            if c < 0x20:
                c |= 0x40           # inverse capitals
            row.append(c & 0x7f)
        out.append(row.decode('latin-1'))
    return out


def run_screen(args, suite):
    name, text, keys = suite
    work, disk, problem = setup(args, 'a2s-' + name + '-', trstest.to_trs(text), keys + r'\xff\x0c\xff')
    if not problem:
        problem = bobbin(args, work, disk)
    lines = [problem] if problem else []
    got, want = (args.dos.get(work, disk, f'screen{n}') for n in (1, 2))
    if not lines and not (got and want):
        lines.append('  the keys did not get to the end')
    if not lines:
        got, want = rows(args, got), rows(args, want)
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


def default_jar():
    """AC_JAR, else an AppleCommander ac jar in ~/Downloads"""
    if os.environ.get('AC_JAR'):
        return os.environ['AC_JAR']
    jars = sorted(glob.glob(os.path.expanduser('~/Downloads/AppleCommander-ac-*.jar')))
    return jars[-1] if jars else ''


def main():
    ap = argparse.ArgumentParser(description='p8vi tests on an Apple II with DOS 3.3 or ProDOS in bobbin')
    ap.add_argument('kind', nargs='?', default='files', choices=['files', 'screen', 'number'])
    ap.add_argument('names', nargs='*', help='only run these suites')
    ap.add_argument('--prodos', action='store_true', help='the ProDOS build (p8vi-prodostest.sys)')
    ap.add_argument('--prodosx', action='store_true', help='the ProDOS 128 KB build (p8vi-prodosxtest.sys)')
    ap.add_argument('--ram', type=int, help="bobbin's RAM in KB (64: no aux memory)")
    ap.add_argument('--prg', help='the test build')
    ap.add_argument('--disk', help='a disk that boots the DOS (A2_DISK, PRODOS_DISK)')
    ap.add_argument('--ac', default=default_jar(), help="AppleCommander's ac jar (AC_JAR)")
    ap.add_argument('--work', default='build')
    ap.add_argument('-j', type=int, default=6)
    ap.add_argument('--skip', action='append', default=[], metavar='SUITE')
    args = ap.parse_args()
    if args.prodos or args.prodosx:
        args.dos = Prodos(args.ac)
        args.prg = args.prg or ('build/p8vi-prodosxtest.sys' if args.prodosx else 'build/p8vi-prodostest.sys')
        if args.prodosx:
            # (more than aux memory's 44 pages hold: huge is about 87 KB of
            # text, bigundo 30 KB with its undo and a yank of it; as on the
            # TRS-80 4x and the C128's bank 1)
            args.dos.no_room = ['huge', 'bigundo']
            args.dos.name = 'ProDOS 128 KB'
        args.disk = args.disk or os.environ.get(
            'PRODOS_DISK', os.path.expanduser('~/.local/share/bobbin/images/prodos242.dsk'))
    else:
        args.dos = Dos33()
        args.prg = args.prg or 'build/p8vi-appleiitest.bin'
        args.disk = args.disk or os.environ.get('A2_DISK', 'build/dos33.dsk')
        if args.kind == 'number':
            sys.exit('number is for the ProDOS build (--prodos): the DOS 3.3 one has no :set number')
    for what, path in [('bobbin', BOBBIN)] + args.dos.tools(args) + [(f'the {args.dos.name} disk', args.disk)]:
        if not path or not os.path.exists(path):
            print(f'{what} not found: the {args.dos.name} tests are skipped')
            sys.exit(0)
    args.prg = os.path.abspath(args.prg)
    args.disk = os.path.abspath(args.disk)
    args.work = os.path.abspath(args.work)
    args.exit = exit_address(args.prg)
    wanted = lambda s: (not args.names or s[0] in args.names) and s[0] not in args.skip
    if args.kind == 'files':
        suites = [s for s in edtest.FILE_SUITES + (edtest.REU_SUITES if args.prodosx else [])
                  if wanted(s) and (args.names or s[0] not in trstest.CBM_ONLY + args.dos.no_room)]
        run_suite = run_files
    elif args.kind == 'screen':
        suites = [s for s in edtest.SCREEN_SUITES if wanted(s)]
        run_suite = run_screen
    else:
        suites = [s for s in edtest.SCREEN_SUITES + cpmtest.NUMBER_SUITES if wanted(s)]
        run_suite = run_number
    if not suites:
        sys.exit('no such suite')
    failed = 0
    with ThreadPoolExecutor(max_workers=args.j) as pool:
        for name, ok, lines in pool.map(lambda s: run_suite(args, s), suites):
            print(f'{name}: {"ok" if ok else "FAIL"}', flush=True)
            for line in lines:
                print(line)
            failed += not ok
    print(f'{args.dos.name} {args.kind}: {len(suites) - failed} of {len(suites)} passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
