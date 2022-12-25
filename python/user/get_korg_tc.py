#!/usr/bin/env python3

from argparse import ArgumentParser
import os
from pathlib import Path
import shlex

import lib_kernel
import lib_user

if __name__ == '__main__':
    parser = ArgumentParser(
        description='Print CROSS_COMPILE value for kernel.org toolchains on disk')

    parser.add_argument('version', choices=lib_kernel.supported_korg_gcc_versions(), type=int)
    parser.add_argument('arch', choices=lib_kernel.supported_korg_gcc_arches())

    args = parser.parse_args()

    target = lib_kernel.korg_gcc_canonicalize_target(args.arch)
    version = lib_user.get_latest_gcc_version(args.version)

    cross_compile = Path(os.environ['CBL_TC_STOW_GCC'], version, 'bin', target + '-')

    print(f"CROSS_COMPILE={shlex.quote(str(cross_compile))}")
