#!/usr/bin/env python3
"""The editor's tests for the classic Macintosh version, on a Macintosh
Plus in MAME, without a window.

    mactest.py [files|screen|number|endings] [--prg build/p8vi-macplustest.bin]
               [--system DISK] [--roms DIR] [-j N] [--skip SUITE] [name...]

Runs tests/vice/edtest.py's suites with the test build (features.KEYFILE),
which plays the keys in KEYS.TXT before it reads the keyboard.  For each
suite, in a directory of its own (as p8p8's tests/macrun.sh does):

  - a copy of the system disk (an 800 KB disk a Macintosh Plus starts
    from: System 6.0.8's System Tools, by default) loses the files beside
    its System Folder (room), and gets p8vi in its System Folder as the Finder, the program the
    machine starts, with an empty p8p8.out beside it: the library then
    ends the program without waiting for a key, and says in the system's
    Scratch8 that it ended, where a script of MAME's sees it
  - KEYS.TXT gets ":e t.txt", the suite's keys and ":q!" as the editor's
    key codes (edtest's: \\n RETURN, \\x1b Escape, ...), t.txt the text
    (CR line endings)
  - the files left in the System Folder are compared with the suite's (CR
    LF and CR as LF)
  - (screen) the key $ff has the test build write the window's characters
    to SCREEN1.BIN, the next $ff to SCREEN2.BIN: the screen after the
    suite's keys must be the same as after a full redraw (Ctrl-L)
  - (number) the screen suites again with :set number first, and
    tests/cpm/cpmtest.py's NUMBER_SUITES
  - (endings) a new text's line endings as written: CR

MAME is MAME (the path), else mame on the PATH.  The ROMs (MAME's macplus
set) are in MAC_ROMS, the system disk is MAC_SYSTEM, by default
~/Emulation/Classic/ROM and ~/Emulation/Classic/Work/System Tools.img.
(System 4.2, the "System 5.0" disk, loses the first block of a screen
dump in 4 of the screen suites, in MAME: sometimes a block of a file just
written is NULs on the disk.  6.0.8 doesn't.)
Needs hfsutils (hmount, hcopy, hls, hrename).
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
import cpmtest  # noqa: E402  (NUMBER_SUITES, ENDING_CASES)

MAME = os.environ.get('MAME') or shutil.which('mame')
ROMS = os.environ.get('MAC_ROMS') or os.path.expanduser('~/Emulation/Classic/ROM')
SYSTEM = os.environ.get('MAC_SYSTEM') or os.path.expanduser('~/Emulation/Classic/Work/System Tools.img')
# the machine's time (seconds), and the host's for one run
TIMEOUT = 120
# the test build's key buffer (KEY_BUF_SIZE in src/macplus/platform.p8)
KEY_BUF_SIZE = 1024

# MAME's script: ends the machine two seconds after the program says it is
# done (P8P8DONE in Scratch8: what it wrote last may not be in the disk's
# image before), at a system error (DSErrCode), or at the time limit; the
# reason, if not done, into the file "trace"
LUA = r'''
local mem = manager.machine.devices[":maincpu"].spaces["program"]
local frames = 0
local started = false
local errors = 0
local done_at = nil
local function finish(what)
    if what then
        local f = io.open("trace", "w"); f:write(what, "\n"); f:close()
    end
    manager.machine:exit()
end
emu.register_frame_done(function()
    frames = frames + 1
    if not started then
        -- CurApName: the application (as the Finder) has been started
        if mem:read_u32(0x910) == 0x0646696e and mem:read_u16(0x914) == 0x6465 then
            started = true
            errors = mem:read_u16(0xaf0)
        end
    elseif done_at then
        -- (two seconds more: the drive writes its last track into the
        -- disk's image meanwhile)
        if frames >= done_at then finish(nil) end
    elseif mem:read_u32(0x9fa) == 0x50385038 and mem:read_u32(0x9fe) == 0x444f4e45 then
        done_at = frames + 120
    elseif mem:read_u16(0xaf0) ~= errors then
        errors = mem:read_u16(0xaf0)
        if errors ~= 0 then finish("system error " .. errors) end
    end
    if frames >= TIME * 60 then
        finish(started and "time limit" or "not started")
    end
end)
'''


def hfs(work, *command, **kw):
    """an hfsutils command, with its own home directory (where hfsutils keeps
    the disk that is mounted)"""
    env = dict(os.environ, HOME=work)
    return subprocess.run(command, cwd=work, env=env, stdin=subprocess.DEVNULL,
                          capture_output=True, **kw)


def mac(args, work, files, fetch):
    """run p8vi on a copy of the system disk, files ({name: bytes}) beside it
    in the System Folder; returns (problem, {name: bytes or None}) for the
    names in fetch, as the run left them"""
    disk = os.path.join(work, 'boot.dsk')
    with open(args.system, 'rb') as f, open(disk, 'wb') as d:
        d.write(f.read(819200))
    if hfs(work, 'hmount', disk).returncode:
        return 'hmount failed', {}
    top = hfs(work, 'hls', '-1F').stdout.decode('mac_roman').splitlines()
    folder = next((n[:-1] for n in top if n.lower().startswith('system') and n.endswith(':')), 'System Folder')
    # (room: the files beside the System Folder go, the Finder's Desktop stays)
    for n in top:
        if not n.endswith(':') and n.lower() != 'desktop':
            hfs(work, 'hdel', n.rstrip('*'))
    hfs(work, 'hcopy', '-m', args.prg, f':{folder}:')
    name = open(args.prg, 'rb').read(64)
    name = name[2:2 + name[1]].decode('mac_roman')
    hfs(work, 'hrename', f':{folder}:Finder', f':{folder}:Finder was')
    if hfs(work, 'hrename', f':{folder}:{name}', f':{folder}:Finder').returncode:
        hfs(work, 'humount')
        return 'the application did not go onto the disk (no room?)', {}
    for fname, data in dict(files, **{'p8p8.out': b''}).items():
        local = os.path.join(work, 'in-' + fname)
        with open(local, 'wb') as f:
            f.write(data)
        hfs(work, 'hcopy', '-r', local, f':{folder}:{fname}')
    hfs(work, 'humount')
    with open(os.path.join(work, 'run.lua'), 'w') as f:
        f.write(LUA.replace('TIME', str(TIMEOUT)))
    command = [MAME, 'macplus', '-rompath', args.roms, '-kbd', '', '-flop1', 'boot.dsk',
               '-video', 'none', '-sound', 'none', '-nothrottle', '-skip_gameinfo',
               '-autoboot_script', 'run.lua', '-cfg_directory', 'cfg', '-nvram_directory', 'nvram']
    env = dict(os.environ, SDL_VIDEODRIVER='dummy', SDL_AUDIODRIVER='dummy')
    problem = ''
    try:
        with open(os.path.join(work, 'mame.out'), 'wb') as out:
            subprocess.run(command, cwd=work, env=env, stdin=subprocess.DEVNULL, stdout=out,
                           stderr=subprocess.STDOUT, timeout=TIMEOUT + 60)
    except subprocess.TimeoutExpired:
        problem = f'MAME did not finish in {TIMEOUT + 60} s'
    trace = os.path.join(work, 'trace')
    if not problem and os.path.exists(trace):
        problem = open(trace).read().strip()
    got = {}
    if hfs(work, 'hmount', disk).returncode:
        return problem or 'hmount failed after the run', got
    for fname in fetch:
        local = os.path.join(work, 'out-' + fname)
        r = hfs(work, 'hcopy', '-r', f':{folder}:{fname}', local)
        got[fname] = open(local, 'rb').read() if r.returncode == 0 and os.path.exists(local) else None
    hfs(work, 'humount')
    return problem, got


def mac_text(text):
    """a text with CR line endings (CR LF stays CR LF)"""
    return text.replace(b'\r\n', b'\0').replace(b'\n', b'\r').replace(b'\0', b'\r\n')


def setup(args, prefix, keys, start=':e t.txt\\n', end=':q!\\n'):
    """a directory and the key file's bytes: (work, keys, problem)"""
    work = tempfile.mkdtemp(prefix=prefix, dir=args.work)
    played = trstest.key_bytes(start + keys + end)
    if len(played) > KEY_BUF_SIZE:
        return work, played, f'  {len(played)} bytes of keys, the test build holds {KEY_BUF_SIZE}'
    return work, played, ''


def finish(work, lines):
    if lines:
        lines.append(f'  (files in {work})')
    else:
        shutil.rmtree(work)
    return lines


def run_files(args, suite):
    name, keys, expected, *text = suite
    start = text[0] if text else edtest.SHORT
    swap = trstest.to_trs if not trstest.looks_ascii(start) else (lambda t: t)
    work, played, problem = setup(args, 'mac-' + name + '-', keys)
    got = {}
    if not problem:
        problem, got = mac(args, work, {'KEYS.TXT': played, 't.txt': mac_text(swap(start))},
                           [f for f, _ in expected])
    lines = [f'  {problem}'] if problem else []
    for fname, want in expected:
        have = got.get(fname)
        if have is not None:
            have = trstest.lf_endings(have)
        if want is not None:
            want = trstest.lf_endings(want)
            want = trstest.to_trs(want) if (name, fname) in trstest.NEW_TEXTS else swap(want)
        if have != want:
            lines += [f'  {fname}: FAIL', f'    want {want!r}', f'    got  {have!r}']
    return name, not lines, finish(work, lines)


def rows(data):
    """a SCREENn.BIN's 25 rows"""
    return [data[r * 80:r * 80 + 80].decode('mac_roman') for r in range(25)]


def run_screen(args, suite):
    name, text, keys = suite
    work, played, problem = setup(args, 'macs-' + name + '-', keys + r'\xff\x0c\xff')
    got = {}
    if not problem:
        problem, got = mac(args, work, {'KEYS.TXT': played, 't.txt': mac_text(trstest.to_trs(text))},
                           ['screen1.bin', 'screen2.bin'])
    lines = [f'  {problem}'] if problem else []
    have, want = got.get('screen1.bin'), got.get('screen2.bin')
    if not lines and not (have and want):
        lines.append('  the keys did not get to the end')
    if not lines:
        have, want = rows(have), rows(want)
        if not ''.join(want).strip():
            lines.append('  the screen is empty')
        diff = [r for r in range(25) if have[r] != want[r]]
        if diff:
            lines.append(f'  differs from the redrawn screen in rows {diff[:8]}')
            for r in diff[:3]:
                lines += [f'    {r:2} want {want[r]!r}', f'    {r:2} got  {have[r]!r}']
    return name, not lines, finish(work, lines)


def run_number(args, suite):
    name, text, keys = suite
    return run_screen(args, (name, text, r':set number\n' + keys))


def run_ending(args, case):
    name, keys, fname = case
    work = tempfile.mkdtemp(prefix='mace-' + name + '-', dir=args.work)
    problem, got = mac(args, work, {'KEYS.TXT': keys}, [fname])
    lines = [f'  {problem}'] if problem else []
    want = b'ab\rcd\r'
    if got.get(fname) != want:
        lines += [f'  {fname}: want {want!r}', f'  {fname}: got  {got.get(fname)!r}']
    return name, not lines, finish(work, lines)


def main():
    ap = argparse.ArgumentParser(description='p8vi tests on a Macintosh Plus in MAME')
    ap.add_argument('kind', nargs='?', default='files', choices=['files', 'screen', 'number', 'endings'])
    ap.add_argument('names', nargs='*', help='only run these suites')
    ap.add_argument('--prg', default='build/p8vi-macplustest.bin', help='the test build')
    ap.add_argument('--system', default=SYSTEM, help='the system disk (800 KB, only read)')
    ap.add_argument('--roms', default=ROMS, help="MAME's ROM directory (macplus)")
    ap.add_argument('--work', default='build')
    ap.add_argument('-j', type=int, default=4)
    ap.add_argument('--skip', action='append', default=[], metavar='SUITE')
    args = ap.parse_args()
    if not MAME or not shutil.which('hmount'):
        print('mame or hfsutils not found (set MAME to its path): the Macintosh tests are skipped')
        sys.exit(0)
    if not os.path.exists(args.system):
        print(f'no system disk {args.system} (set MAC_SYSTEM): the Macintosh tests are skipped')
        sys.exit(0)
    args.prg = os.path.abspath(args.prg)
    args.work = os.path.abspath(args.work)
    args.system = os.path.abspath(args.system)
    args.roms = os.path.abspath(args.roms)
    wanted = lambda s: (not args.names or s[0] in args.names) and s[0] not in args.skip
    if args.kind == 'files':
        suites = [s for s in edtest.FILE_SUITES if wanted(s) and (args.names or s[0] not in trstest.CBM_ONLY)]
        run = run_files
    elif args.kind == 'screen':
        suites = [s for s in edtest.SCREEN_SUITES if wanted(s)]
        run = run_screen
    elif args.kind == 'number':
        suites = [s for s in edtest.SCREEN_SUITES + cpmtest.NUMBER_SUITES if wanted(s)]
        run = run_number
    else:
        suites = [c for c in cpmtest.ENDING_CASES if wanted(c)]
        run = run_ending
    if not suites:
        sys.exit('no such suite')
    failed = 0
    with ThreadPoolExecutor(max_workers=args.j) as pool:
        for name, ok, lines in pool.map(lambda s: run(args, s), suites):
            print(f'{name}: {"ok" if ok else "FAIL"}', flush=True)
            for line in lines:
                print(line)
            failed += not ok
    print(f'Macintosh {args.kind}: {len(suites) - failed} of {len(suites)} passed')
    sys.exit(1 if failed else 0)


if __name__ == '__main__':
    main()
