#!/usr/bin/env python3
"""p8vi's tests on an Atari ST in Hatari (the atarist build).

    sttest.py [files|screen|number|endings|args|big] [--prg build/p8vi-ataristtest.tos] [--tos IMAGE]
              [--rez high|med|low] [--parent build/argsrun.tos] [-j N] [--skip SUITE] [name...]

The suites are tests/cpm/cpmtest.py's, run the way tests/amiga/amigatest.py
runs them, with Hatari in place of tnylpo.  For each suite, in a directory
of its own: t.txt, keys.txt (the keys, the editor's codes) and the test
build (features.KEYFILE: it plays the keys, then quits) as P8VI.TOS.
Hatari runs it with no window, the directory as drive C: and the program
started from the desktop (temp/HATARI.md, p8p8's tests/strun.sh), and its
debugger ends the run at the program's Pterm.

files:   tests/vice/edtest.py's file suites (but CBM_ONLY's): the files
         left are compared with the suite's (CR LF and CR as LF)
endings: a new text's line endings as written (CR LF)
screen, number: edtest's screen suites (number: with :set number, and
         cpmtest.py's NUMBER_SUITES).  The test build writes what it sends
         to the console to OUT.LOG too; tests/cpm/termplay.py plays it back
         as a VT-52 screen of the resolution's size (80 x 25, or 40 x 25
         with --rez low), and the screen when the suite's keys are done
         must be the one after a full redraw (Ctrl-L).  This checks what
         p8vi sends, not how TOS draws it.
args:    p8vi started with a command line (ARGS_CASES), by
         tests/atarist/argsrun.p8 (--parent: Hatari's --auto can't give
         one): the file named is opened before the keys are played
big:     the wide core's 32-bit positions: a 1.3 MB file of 70000 lines,
         edited on both sides of line 65535 (cpmtest.py's big, made
         smaller for the ST's 4 MB); each :w is compared, and :set number's
         screen

The machine is a 4 MB ST with TOS 1.04 (--tos, default ST_TOS or
~/Emulation/AtariST/TOS_104.IMG if it's there, else Hatari's EmuTOS) and a
monochrome monitor (--rez high); --rez med and low use a colour one.
Hatari is HATARI (the path), else on the PATH; without it the tests are
skipped (exit status 0).
"""

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor

sys.dont_write_bytecode = True
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'cpm'))
import cpmtest  # noqa: E402
import termplay  # noqa: E402
import trstest  # noqa: E402  (cpmtest's path has it)

HATARI = os.environ.get('HATARI') or shutil.which('hatari')
TOS_104 = os.path.expanduser('~/Emulation/AtariST/TOS_104.IMG')
TIMEOUT = 60
TIMEOUT_BIG = 600   # (big)
# the test build's key buffer (KEY_BUF_SIZE in src/atarist/platform.p8)
KEY_BUF_SIZE = 1024
# the screen's size in each resolution, and Hatari's options for it
REZ = {'high': (80, 25, ['--monitor', 'mono']),
       'med': (80, 25, ['--monitor', 'rgb', '--tos-res', 'med']),
       'low': (40, 25, ['--monitor', 'rgb', '--tos-res', 'low'])}
ARGS = None


def hatari(work, *options, parent=False):
    """run p8vi in work (cpmtest's setup put it there as p8vi.com), or with
    parent argsrun.p8 (ARGS.parent, which starts it): what it sent to the
    console (OUT.LOG: b'' if there's none), or None if it didn't end"""
    os.replace(os.path.join(work, 'p8vi.com'), os.path.join(work, 'P8VI.TOS'))
    auto = 'P8VI.TOS'
    if parent:
        shutil.copyfile(ARGS.parent, os.path.join(work, 'ARGSRUN.TOS'))
        auto = 'ARGSRUN.TOS'
    # (the debugger ends Hatari at the program's Pterm: GEMDOS $4c, or 0;
    # with the parent only at its Pterm0, not p8vi's Pterm)
    quit_ini = os.path.join(work, 'quit.ini')
    debug_ini = os.path.join(work, 'debug.ini')
    with open(quit_ini, 'w') as f:
        f.write('quit\n')
    with open(debug_ini, 'w') as f:
        if not parent:
            f.write(f'b GemdosOpcode = 0x4c :trace :file {quit_ini}\n')
        f.write(f'b GemdosOpcode = 0 :trace :file {quit_ini}\n')
    cmd = [HATARI, '--machine', 'st', '--memsize', '4'] + REZ[ARGS.rez][2]
    if ARGS.tos:
        cmd += ['--tos', ARGS.tos]
    cmd += ['--fast-boot', 'true', '--harddrive', work, '--sound', 'off', '--fast-forward', 'true',
            '--confirm-quit', 'false', '--log-level', 'fatal', '--parse', debug_ini,
            '--auto', 'C:\\' + auto]
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy')
    try:
        r = subprocess.run(cmd, cwd=work, stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
                           stderr=subprocess.STDOUT, env=env, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        return None
    with open(os.path.join(work, 'hatari.log'), 'wb') as f:
        f.write(r.stdout)
    if b'GemdosOpcode = 0' not in r.stdout:
        return None
    path = os.path.join(work, 'OUT.LOG')
    if not os.path.exists(path):
        return b''
    with open(path, 'rb') as f:
        return f.read()


def screen_of(args, name, text, keys):
    """the screen when the keys are done (their $ff mark), or a problem (a
    string)"""
    work, problem = cpmtest.setup(args, f'sts-{name}-', text, keys)
    if problem:
        return problem
    out = hatari(work)
    if out is None:
        return f'p8vi did not finish in {TIMEOUT} s (files in {work})'
    out = termplay.at_mark(out)
    if out is None:
        return f'the keys did not get to the end (files in {work})'
    w, h, _ = REZ[args.rez]
    try:
        scr, _ = termplay.play(out, 'vt52', w, h)
    except termplay.BadCode as e:
        return f'{e} (files in {work})'
    shutil.rmtree(work)
    return scr


def run_screen(args, suite):
    name, text, keys = suite
    text = trstest.to_trs(text)
    got, want = (screen_of(args, name, text, keys + extra + r'\xff') for extra in ('', r'\x0c'))
    for scr in (got, want):
        if isinstance(scr, str):
            return name, False, ['  ' + scr]
    lines = []
    if not ''.join(want).strip():
        lines.append('  the screen is empty')
    diff = [r for r in range(len(want)) if got[r] != want[r]]
    if diff:
        lines.append(f'  differs from the redrawn screen in rows {diff[:8]}')
        for r in diff[:3]:
            lines += [f'    {r:2} want {want[r]!r}', f'    {r:2} got  {got[r]!r}']
    return name, not lines, lines


def run_number(args, suite):
    name, text, keys = suite
    return run_screen(args, (name, text, r':set number\n' + keys))


# (args) name, the command line, the keys, the files left (None: not
# there); t.txt is SHORT_TEXT.  The usage line's cases end before p8vi
# opens anything.
SHORT_TEXT = b'one\r\ntwo\r\nthree\r\n'
ARGS_CASES = [
    ('file', 'T.TXT', 'x:w\r:q!\r', [('T.TXT', b'ne\r\ntwo\r\nthree\r\n')]),
    ('lower-case', 't.txt', 'jx:w\r:q!\r', [('T.TXT', b'one\r\nwo\r\nthree\r\n')]),
    ('path', 'C:\\T.TXT', 'Gx:w\r:q!\r', [('T.TXT', b'one\r\ntwo\r\nhree\r\n'), ('P8VI.TMP', None)]),
    ('new-file', 'NEW.TXT', 'iab\x1b:w\r:q!\r', [('NEW.TXT', b'ab\r\n')]),
    ('none', '', ':w n.txt\r:q!\r', [('N.TXT', b'\r\n')]),
    ('two-files', 'T.TXT U.TXT', 'x:w\r:q!\r', [('T.TXT', SHORT_TEXT)]),
    ('option', '-x T.TXT', 'x:w\r:q!\r', [('T.TXT', SHORT_TEXT)]),
]


def run_args(args, case):
    name, tail, keys, expected = case
    work = tempfile.mkdtemp(prefix=f'starg-{name}-', dir=args.work)
    shutil.copyfile(args.prg, os.path.join(work, 'p8vi.com'))
    with open(os.path.join(work, 'T.TXT'), 'wb') as f:
        f.write(SHORT_TEXT)
    with open(os.path.join(work, 'TAIL.TXT'), 'w') as f:
        f.write(tail)
    with open(os.path.join(work, 'KEYS.TXT'), 'wb') as f:
        f.write(keys.encode())
    lines = []
    if hatari(work, parent=True) is None:
        lines.append(f'  did not finish in {TIMEOUT} s')
    for fname, want in expected:
        path = os.path.join(work, fname)
        got = open(path, 'rb').read() if os.path.exists(path) else None
        if got != want:
            lines += [f'  {fname}: want {want!r}', f'  {fname}: got  {got!r}']
    if lines:
        lines.append(f'  (files in {work})')
    else:
        shutil.rmtree(work)
    return name, not lines, lines


def run_big(args, _):
    """the 32-bit positions on a big file"""
    import random
    work = tempfile.mkdtemp(prefix='stbig-', dir=args.work)
    shutil.copyfile(args.prg, os.path.join(work, 'p8vi.com'))
    random.seed(2)
    lines = [f'line {i:06d} '.encode() + b'x' * random.randint(0, 10) for i in range(1, 70001)] + [b'']
    with open(os.path.join(work, 'BIG.TXT'), 'wb') as f:
        f.write(b'\r\n'.join(lines))
    keys = (':e big.txt\r' 'G:w g1\r' '/line 066000\rdd:w g2\r' 'ggx:w g3\r' '5Gyy' 'Gp:w g4\r' 'u:w g5\r'
            ':66002\rdd:w g6\r' 'u:65998,66001s/line/LINE/\r:w g7\r' 'u:set number\r:65999\r\xff' ':q!\r')
    with open(os.path.join(work, 'KEYS.TXT'), 'wb') as f:
        f.write(keys.encode('latin-1'))
    out = hatari(work)
    if out is None:
        return 'big', False, [f'  did not finish in {TIMEOUT} s (files in {work})']
    # lines[n - 1] is line n
    l2 = lines[:65999] + lines[66000:]
    l3 = [l2[0][1:]] + l2[1:]
    want = {'G1': lines, 'G2': l2, 'G3': l3, 'G4': l3[:-1] + [l3[4], b''], 'G5': l3,
            'G6': l3[:66001] + l3[66002:],
            'G7': l3[:65997] + [x.replace(b'line', b'LINE') for x in l3[65997:66001]] + l3[66001:]}
    problems = []
    for name, want_lines in want.items():
        path = os.path.join(work, name)
        got = open(path, 'rb').read() if os.path.exists(path) else None
        if got != b'\r\n'.join(want_lines):
            problems.append(f'  {name}: not the text it should be')
    mark = termplay.at_mark(out)
    scr, _ = termplay.play(mark or b'', 'vt52', 80, 25)
    if not any(row.startswith('   65999 line 065999 ') for row in scr):
        problems.append('  :set number: no row starts with line 65999 and its number')
    if problems:
        problems.append(f'  (files in {work})')
    else:
        shutil.rmtree(work)
    return 'big', not problems, problems


def main():
    global ARGS, TIMEOUT
    ap = argparse.ArgumentParser(description=__doc__.split('\n\n')[0])
    ap.add_argument('kind', nargs='?', default='files', choices=['files', 'screen', 'number', 'endings', 'args', 'big'])
    ap.add_argument('names', nargs='*', help='only run these suites')
    ap.add_argument('--prg', default='build/p8vi-ataristtest.tos')
    ap.add_argument('--tos', default=os.environ.get('ST_TOS') or (TOS_104 if os.path.exists(TOS_104) else None),
                    help="the TOS image (default: ST_TOS, else TOS 1.04 if it's there, else EmuTOS)")
    ap.add_argument('--rez', choices=list(REZ), default='high', help='the screen resolution (default high)')
    ap.add_argument('--parent', default='build/argsrun.tos', help='(args) tests/atarist/argsrun.p8, built')
    ap.add_argument('--work', default='build')
    ap.add_argument('-j', type=int, default=6)
    ap.add_argument('--skip', action='append', default=[], metavar='SUITE')
    args = ap.parse_args()
    if not HATARI:
        print('hatari not found (set HATARI to its path): the Atari ST tests are skipped')
        sys.exit(0)
    args.prg = os.path.abspath(args.prg)
    args.parent = os.path.abspath(args.parent)
    args.work = os.path.abspath(args.work)
    args.host = False
    ARGS = args
    # cpmtest's set-up and checks, with Hatari for tnylpo
    cpmtest.ARGS = args
    cpmtest.KEY_BUF_SIZE = KEY_BUF_SIZE
    cpmtest.tnylpo = hatari
    wanted = lambda s: (not args.names or s[0] in args.names) and s[0] not in args.skip
    if args.kind == 'endings':
        cpmtest.NEW_EOL = b'\r\n'
        suites = [c for c in cpmtest.ENDING_CASES if wanted(c)]
        run = cpmtest.run_ending
    elif args.kind == 'args':
        suites = [c for c in ARGS_CASES if wanted(c)]
        run = run_args
    elif args.kind == 'big':
        TIMEOUT = TIMEOUT_BIG
        suites = [('big',)]
        run = run_big
    elif args.kind == 'screen':
        suites = [s for s in cpmtest.edtest.SCREEN_SUITES if wanted(s)]
        run = run_screen
    elif args.kind == 'number':
        suites = [s for s in cpmtest.edtest.SCREEN_SUITES + cpmtest.NUMBER_SUITES if wanted(s)]
        run = run_number
    else:
        suites = [s for s in cpmtest.edtest.FILE_SUITES
                  if wanted(s) and (args.names or s[0] not in cpmtest.CBM_ONLY)]
        run = cpmtest.run_files
    if not suites:
        sys.exit('no such suite')
    failed = 0
    with ThreadPoolExecutor(max_workers=args.j) as pool:
        for name, ok, lines in pool.map(lambda s: run(args, s), suites):
            print(f'{name}: {"ok" if ok else "FAIL"}', flush=True)
            for line in lines:
                print(line)
            failed += not ok
    tos = os.path.basename(args.tos) if args.tos else 'EmuTOS'
    print(f'Atari ST {args.kind} ({tos}, {args.rez}): {len(suites) - failed} of {len(suites)} passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
