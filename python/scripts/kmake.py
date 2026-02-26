#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import os
import shutil
import sys
from argparse import ArgumentParser
from pathlib import Path

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.kernel

# pylint: enable=wrong-import-position


def parse_arguments():
    parser = ArgumentParser(description='A make wrapper for building Linux kernels')

    parser.add_argument('-C',
                        '--directory',
                        default=Path(),
                        help='Mirrors the equivalent make argument',
                        type=Path)
    parser.add_argument('--no-ccache', action='store_true', help='Disable the use of ccache')
    parser.add_argument(
        '--omit-hostldflags',
        action='store_true',
        help=
        'By default, kmake will manipulate HOSTLDFLAGS in certain cases. This option avoids that logic.',
    )
    parser.add_argument(
        '--omit-o-arg',
        action='store_true',
        help=
        'By default, kmake uses an O= value if one is not present, overriding the default of building in tree. This option avoids that logic.',
    )
    parser.add_argument(
        '-p',
        '--prepend-to-path',
        action='append',
        help='Prepend specified directory to PATH (can be specified multiple times)')
    parser.add_argument('-j', '--jobs', default=os.cpu_count(), help='Number of jobs', type=int)
    parser.add_argument('--use-time', action='store_true', help="Call 'time -v' for time tracking")
    parser.add_argument('-v', '--verbose', action='store_true', help='Do a more verbose build')
    parser.add_argument('make_args', help='Make variables and targets', nargs='*')

    return parser.parse_intermixed_args()


def prepend_to_path(paths):
    if not paths:
        return
    for path in paths:
        if not Path(path).exists():
            raise RuntimeError(f"Requested path addition ('{path}') does not exist?")
    os.environ['PATH'] = os.pathsep.join(paths) + os.pathsep + os.environ['PATH']


if __name__ == '__main__':
    args = parse_arguments()

    prepend_to_path(args.prepend_to_path)

    variables = {}
    targets = []
    for arg in args.make_args:
        if '=' in arg:
            variables.update([arg.split('=', 1)])
        # Basically an ordered set
        elif arg not in targets:
            targets.append(arg)

    if not args.omit_hostldflags:
        hostldflags = hostldflags_var.split(' ') if (hostldflags_var := variables.get(
            'HOSTLDFLAGS', '')) else []
        if (llvm := variables.get('LLVM', '')):
            # Use ld.lld as the host linker by default with LLVM=
            if llvm == '1':
                LLD = 'ld.lld'
            elif llvm.startswith('-'):
                LLD = f"ld.lld{llvm}"
            elif llvm.endswith('/'):
                LLD = f"{llvm}ld.lld"
            else:
                LLD = None  # invalid LLVM value, we'll fail later
            specified_ld = '-fuse-ld=' in hostldflags_var or '--ld-path=' in hostldflags_var
            if LLD and not specified_ld and (lld_path := shutil.which(LLD)):
                hostldflags.append(f"--ld-path={lld_path}")
        # Avoid .sframe mismatch error
        # https://lore.kernel.org/59805735-5e41-44b7-a250-5bedcb80a75e@oracle.com/
        # elif '--discard-sframe' in lib.utils.chronic(['ld', '--help']).stdout:
        #     hostldflags.append('-Wl,--discard-sframe')
        if hostldflags:
            variables['HOSTLDFLAGS'] = ' '.join(hostldflags)

    if 'O' not in variables and not args.omit_o_arg:
        # tbf implemented in Python
        if 'TMP_BUILD_FOLDER' in os.environ:
            if os.environ['CBL_SRC_W'] in (src := args.directory.resolve()).as_posix():
                BASE = '-'.join(src.parts[-2:])
            else:
                BASE = src.name
            variables['O'] = Path(os.environ['TMP_BUILD_FOLDER'], BASE)
        else:
            variables['O'] = Path('build')

    lib.kernel.kmake(variables,
                     targets,
                     ccache=(not args.no_ccache),
                     directory=args.directory,
                     jobs=args.jobs,
                     silent=(not args.verbose),
                     use_time=args.use_time)
