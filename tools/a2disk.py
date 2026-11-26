#!/usr/bin/env python3
"""Make an Apple II disk with p8vi on it, for make emu-appleii and emu-prodos.

    a2disk.py DOS33.dsk OUT.dsk p8vi-appleii.bin [text files...]
    a2disk.py --prodos PRODOS.dsk OUT.dsk p8vi-prodos.sys [text files...]

OUT.dsk is a copy of the first disk (one that boots DOS 3.3, such as the
system master, or ProDOS, such as bobbin's images/prodos242.dsk) with the
program and each text file as a file of its name in capitals (sample.txt
is SAMPLE.TXT), with CR line endings (from LF or CR LF).

DOS 3.3, with dos33 (dos33fsprogs, DOS33 or on the PATH): the program as
the B file P8VI (p8c's .bin already has BSAVE's address and length before
it), the texts as T files (bit 7 set on each character, a 0 at the end).
ProDOS, with AppleCommander's ac (the jar AC_JAR, run with java): the
program as P8VI.SYSTEM, type SYS for $2000, the texts as TXT files.
Files already there are replaced.
"""

import glob
import os
import shutil
import subprocess
import sys
import tempfile

DOS33 = os.environ.get('DOS33') or shutil.which('dos33')


def ac_jar():
    if os.environ.get('AC_JAR'):
        return os.environ['AC_JAR']
    jars = sorted(glob.glob(os.path.expanduser('~/Downloads/AppleCommander-ac-*.jar')))
    return jars[-1] if jars else None


def call(command, data=None):
    r = subprocess.run(command, input=data, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    return r.returncode, r.stdout.decode(errors='replace').strip()


def put_dos33(disk, kind, path, name):
    call([DOS33, '-y', disk, 'UNLOCK', name])
    call([DOS33, '-y', disk, 'DELETE', name])
    code, out = call([DOS33, '-y', disk, 'SAVE', kind, path, name])
    if code != 0:
        sys.exit(f'dos33 SAVE {name}: {out}')


def put_prodos(jar, disk, name, ftype, data, address=None):
    call(['java', '-jar', jar, '-d', disk, name])
    code, out = call(['java', '-jar', jar, '-p', disk, name, ftype] + ([address] if address else []), data)
    if code != 0:
        sys.exit(f'ac -p {name}: {out}')


def main():
    args = sys.argv[1:]
    prodos = args[:1] == ['--prodos']
    if prodos:
        args = args[1:]
    if len(args) < 3:
        sys.exit(__doc__)
    src, out, prg, *texts = args
    if not os.path.exists(src):
        sys.exit(f'{src}: no disk (set A2_DISK or PRODOS_DISK to one that boots the DOS)')
    jar = ac_jar() if prodos else None
    if prodos and not (jar and os.path.exists(jar) and shutil.which('java')):
        sys.exit("AppleCommander's ac jar (AC_JAR) or java not found")
    if not prodos and not DOS33:
        sys.exit('dos33 (dos33fsprogs) not found: set DOS33 to its path')
    shutil.copyfile(src, out)
    if prodos:
        with open(prg, 'rb') as f:
            put_prodos(jar, out, 'P8VI.SYSTEM', 'SYS', f.read(), '0x2000')
    else:
        put_dos33(out, 'B', prg, 'P8VI')
    with tempfile.TemporaryDirectory() as tmp:
        for path in texts:
            with open(path, 'rb') as f:
                text = f.read().replace(b'\r\n', b'\r').replace(b'\n', b'\r')
            name = os.path.basename(path).upper()
            if prodos:
                put_prodos(jar, out, name, 'TXT', text)
            else:
                t = os.path.join(tmp, 't')
                with open(t, 'wb') as f:
                    f.write(bytes(c | 0x80 for c in text) + b'\0')
                put_dos33(out, 'T', t, name)
    print(f'{out}: p8vi and {len(texts)} text files')


if __name__ == '__main__':
    main()
