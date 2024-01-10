#!/usr/bin/env python3

from argparse import ArgumentParser
import os
from pathlib import Path
import re
import subprocess


def call_git(directory, cmd):
    return subprocess.run(['git', *cmd], capture_output=True, check=True, cwd=directory, text=True)


def get_git_output(directory, cmd):
    return call_git(directory, cmd).stdout.strip()


def gen_linux_pkgver(args):
    if not Path(args.directory, 'Makefile').exists():
        raise RuntimeError(
            f"Supplied kernel directory ('{args.directory}') does not appear to be a Linux kernel source tree?",
        )

    if args.update:
        call_git(args.directory, ['remote', 'update', '--prune', args.remote])

    ref = f"{args.remote}/{args.branch}"

    describe = get_git_output(args.directory, ['describe', ref]).replace('-', '.')
    if not (match := re.search(r'v([0-9]+)\.([0-9]+)\.', describe)):
        raise RuntimeError(f"Version regex did not work for '{describe}'?")

    srccommit = get_git_output(args.directory, ['sha', ref])
    print(f"_srccommit={srccommit}")

    # Transform
    #     v<maj_num>.<min_num>.<rev_num>.g<hash>
    # into
    #     v<maj_num>.(<min_num> + 1).rc0.<rev_num>.g<hash>
    pkgver = describe.replace(match[0], f"v{match[1]}.{int(match[2]) + 1}.rc0.")
    print(f"pkgver={pkgver}")


def parse_arguments():
    parser = ArgumentParser(
        description='Generate _srccommit and pkgver for PKGBUILD based on remote reference')

    parser.add_argument('-b',
                        '--branch',
                        default='master',
                        help='Name of branch on remote (default: %(default)s)')
    parser.add_argument('-C',
                        '--directory',
                        default=Path(os.environ['CBL_SRC'], 'linux'),
                        help='Repository to run git commands in (default: %(default)s)',
                        type=Path)
    parser.add_argument('-r',
                        '--remote',
                        default='origin',
                        help='Name of remote (default: %(default)s)')
    parser.add_argument('-u',
                        '--update',
                        action='store_true',
                        help='Update remote before generating version (default: no update)')

    return parser.parse_args()


if __name__ == '__main__':
    gen_linux_pkgver(parse_arguments())
