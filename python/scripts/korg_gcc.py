#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

import argparse
import os
from pathlib import Path
import platform
import shlex
import subprocess
import sys

import requests

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.sha256  # noqa: E402
import lib.utils  # noqa: E402
# pylint: enable=wrong-import-position


def korg_gcc_canonicalize_target(value):
    if 'linux' in value:
        return value

    suffix = ''
    if value == 'arm':
        suffix = '-gnueabi'

    # in case the kernel ARCH value is passed in, we make an educated guess as
    # to what the user intended
    kernel_to_gcc = {
        'arm64': 'aarch64',
        'loongarch': 'loongarch64',
        'riscv': 'riscv64',
    }
    return f"{kernel_to_gcc.get(value, value)}-linux{suffix}"


def supported_korg_gcc_arches():
    return [
        'aarch64',
        'arm',
        'arm64',  # accept kernel value for aarch64
        'i386',
        'loongarch',  # accept kernel value for loongarch64
        'loongarch64',
        'm68k',
        'mips',
        'mips64',
        'powerpc',
        'powerpc64',
        'riscv',  # accept kernel value for riscv64
        'riscv32',
        'riscv64',
        's390',
        'x86_64',
    ]  # yapf: disable


def supported_korg_gcc_targets():
    return [korg_gcc_canonicalize_target(arch) for arch in supported_korg_gcc_arches()]


# GCC 5 through 13
def supported_korg_gcc_versions():
    return list(range(5, 14))


def get_gcc_cross_compile(major_version, arch_or_target):
    version = get_latest_gcc_version(major_version)
    target = korg_gcc_canonicalize_target(arch_or_target)

    return f"{os.environ['CBL_TC_GCC_STORE']}/{version}/bin/{target}-"


def get_latest_gcc_version(major_version):
    return {
        5: '5.5.0',
        6: '6.5.0',
        7: '7.5.0',
        8: '8.5.0',
        9: '9.5.0',
        10: '10.4.0',
        11: '11.4.0',
        12: '12.3.0',
        13: '13.2.0',
    }[major_version]


def parse_arguments():
    supported_arches = supported_korg_gcc_arches()
    supported_targets = supported_korg_gcc_targets()
    supported_versions = supported_korg_gcc_versions()

    parser = argparse.ArgumentParser()
    subparser = parser.add_subparsers(dest='subcommand', metavar='SUBCOMMAND', required=True)

    print_parser = subparser.add_parser('print',
                                        help='Print CROSS_COMPILE variable for use with make')
    print_parser.add_argument('-s',
                              '--split',
                              action='store_true',
                              help='Split CROSS_COMPILE for use with kmake')
    print_parser.add_argument('version', choices=supported_versions, type=int)
    print_parser.add_argument('arch', choices=supported_arches)

    install_parser = subparser.add_parser(
        'install', help='Download and/or extact kernel.org GCC tarballs to disk')

    install_parser.add_argument('-t',
                                '--targets',
                                choices=supported_arches + supported_targets,
                                default=supported_targets,
                                help='Toolchain targets to download (default: %(default)s)',
                                metavar='TARGETS',
                                nargs='+')

    install_parser.add_argument('-v',
                                '--versions',
                                choices=supported_versions,
                                default=supported_versions,
                                help='Toolchain versions to download (default: %(default)s)',
                                metavar='TARGETS',
                                nargs='+',
                                type=int)

    download_folder_default = Path(os.environ['NAS_FOLDER'], 'kernel.org/toolchains')
    install_folder_default = Path(os.environ['CBL_TC_GCC_STORE'])
    install_parser.add_argument('--download-folder',
                                default=download_folder_default,
                                help='Folder to store downloaded tarballs (default: %(default)s)')
    install_parser.add_argument(
        '--install-folder',
        default=install_folder_default,
        help='Folder to store extracted toolchains for use (default: %(default)s)')

    no_group = install_parser.add_mutually_exclusive_group()
    no_group.add_argument('--no-cache',
                          action='store_true',
                          help='Do not save downloaded toolchain tarballs to disk')
    no_group.add_argument('--no-extract',
                          action='store_true',
                          help='Do not unpack downloaded toolchain tarballs to disk')

    return parser.parse_args()


def install(args):
    cache = not args.no_cache
    extract = not args.no_extract

    if cache and not (download_folder := Path(args.download_folder)).exists():
        raise RuntimeError(
            f"Download folder ('{download_folder}') does not exist, please create it before running this script!",
        )

    host_arch = platform.machine()
    host_arch_gcc = {
        'aarch64': 'arm64',
        'x86_64': 'x86_64',
    }[host_arch]

    for major_version in args.versions:
        targets = sorted({korg_gcc_canonicalize_target(target) for target in args.targets})
        # No GCC 5.5.0 aarch64-linux on aarch64?
        if host_arch == 'aarch64' and major_version == 5:
            targets.remove('aarch64-linux')
        # Ensure 'arm' gets downloaded with 'aarch64', so that compat vDSO can
        # be built.
        if 'aarch64-linux' in targets:
            targets.append('arm-linux-gnueabi')
        # No GCC 9.5.0 i386-linux on x86_64?
        if host_arch == 'x86_64' and major_version == 9:
            targets.remove('i386-linux')
        # RISC-V was not supported in GCC until 7.x
        if major_version < 7:
            targets.remove('riscv32-linux')
            targets.remove('riscv64-linux')
        # LoongArch was not supported in GCC until 12.x
        if major_version < 12:
            targets.remove('loongarch64-linux')

        full_version = get_latest_gcc_version(major_version)

        for target in targets:
            # If we are not saving the tarball to disk and GCC already exists
            # in the expected location, there is nothing to do for this target.
            gcc = Path(args.install_folder, full_version, 'bin', f"{target}-gcc")
            if gcc.exists() and not cache:
                continue

            tarball = Path(args.download_folder, full_version,
                           f"{host_arch_gcc}-gcc-{full_version}-nolibc-{target}.tar.xz")
            if not tarball.exists():
                lib.utils.print_green(f"INFO: Downloading {tarball.name}...")

                url = f"https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/{host_arch_gcc}/{full_version}"
                response = requests.get(f"{url}/{tarball.name}", timeout=3600)
                response.raise_for_status()

                if cache:
                    tarball.parent.mkdir(exist_ok=True, parents=True)
                    tarball.write_bytes(response.content)
                    lib.sha256.validate_from_url(tarball, f"{url}/sha256sums.asc")

            if extract and not gcc.exists():
                (dest_folder := gcc.parents[1]).mkdir(exist_ok=True, parents=True)
                tar_cmd = [
                    'tar',
                    '-C', dest_folder,
                    '--strip-components=2',
                    '-xJ',
                    '-f', tarball if tarball.exists() else '-',
                ]  # yapf: disable

                tar_input = response.content if not tarball.exists() else None
                lib.utils.print_cmd(tar_cmd)
                subprocess.run(tar_cmd, check=True, input=tar_input)


if __name__ == '__main__':
    arguments = parse_arguments()

    if arguments.subcommand == 'install':
        install(arguments)
    if arguments.subcommand == 'print':
        cross_compile = get_gcc_cross_compile(arguments.version, arguments.arch)
        cc_args = []
        if arguments.split:
            cc_args += ['-p', f"{shlex.quote(str(Path(cross_compile).parent))}"]
            cross_compile = Path(cross_compile).name
        cc_args += [f"CROSS_COMPILE={shlex.quote(cross_compile)}"]
        # Ensure compat vDSO gets built for all arm64 compiles
        if arguments.arch in ('aarch64', 'arm64'):
            cross_compile_compat = get_gcc_cross_compile(arguments.version, 'arm')
            if arguments.split:
                cross_compile_compat = Path(cross_compile_compat).name
            cc_args += [f"CROSS_COMPILE_COMPAT={shlex.quote(cross_compile_compat)}"]
        for arg in cc_args:
            print(arg)
