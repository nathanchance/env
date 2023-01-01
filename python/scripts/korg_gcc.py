#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

import argparse
import os
from pathlib import Path
import platform
import shlex
import subprocess

import requests

import lib_sha256
import lib_user


def korg_gcc_canonicalize_target(value):
    if 'linux' in value:
        return value

    suffix = ''
    if value == 'arm':
        suffix = '-gnueabi'
    elif value == 'arm64':  # in case the kernel ARCH value is passed in
        value = 'aarch64'
    return f"{value}-linux{suffix}"


def supported_korg_gcc_arches():
    return [
        'aarch64',
        'arm',
        'i386',
        'm68k',
        'mips',
        'mips64',
        'powerpc',
        'powerpc64',
        'riscv32',
        'riscv64',
        's390',
        'x86_64',
    ]  # yapf: disable


def supported_korg_gcc_targets():
    return [korg_gcc_canonicalize_target(arch) for arch in supported_korg_gcc_arches()]


# GCC 6 through 12, GCC 5 is run in a container
def supported_korg_gcc_versions():
    return list(range(6, 13))


def get_gcc_cross_compile(major_version, arch_or_target):
    version = get_latest_gcc_version(major_version)
    target = korg_gcc_canonicalize_target(arch_or_target)

    return f"{os.environ['CBL_TC_STOW_GCC']}/{version}/bin/{target}-"


def get_latest_gcc_version(major_version):
    return {
        6: '6.5.0',
        7: '7.5.0',
        8: '8.5.0',
        9: '9.5.0',
        10: '10.4.0',
        11: '11.3.0',
        12: '12.2.0',
    }[major_version]


def parse_arguments():
    supported_arches = supported_korg_gcc_arches()
    supported_targets = supported_korg_gcc_targets()
    supported_versions = supported_korg_gcc_versions()

    parser = argparse.ArgumentParser()
    subparser = parser.add_subparsers(dest='subcommand', metavar='SUBCOMMAND', required=True)

    getvar_parser = subparser.add_parser('print',
                                         help='Print CROSS_COMPILE variable for use with make')
    getvar_parser.add_argument('version', choices=supported_versions, type=int)
    getvar_parser.add_argument('arch', choices=supported_arches)

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
    install_folder_default = Path(os.environ['CBL_TC_STOW_GCC'])
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
        raise Exception(
            f"Download folder ('{download_folder}') does not exist, please create it before running this script!"
        )

    host_arch = platform.machine()
    host_arch_gcc = {
        'aarch64': 'arm64',
        'x86_64': 'x86_64',
    }[host_arch]

    for major_version in args.versions:
        print(args.targets)
        targets = sorted({korg_gcc_canonicalize_target(target) for target in args.targets})
        print(targets)
        # No GCC 9.5.0 i386-linux on x86_64?
        if host_arch == 'x86_64' and major_version == 9:
            targets.remove('i386-linux')
        # RISC-V was not supported in GCC until 7.x
        if major_version < 7:
            targets.remove('riscv32-linux')
            targets.remove('riscv64-linux')

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
                lib_user.print_green(f"INFO: Downloading {tarball.name}...")

                url = f"https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/{host_arch_gcc}/{full_version}"
                response = requests.get(f"{url}/{tarball.name}", timeout=3600)
                response.raise_for_status()

                if cache:
                    tarball.parent.mkdir(exist_ok=True, parents=True)
                    tarball.write_bytes(response.content)
                    lib_sha256.validate_from_url(tarball, f"{url}/sha256sums.asc")

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
                subprocess.run(tar_cmd, check=True, input=tar_input)


if __name__ == '__main__':
    arguments = parse_arguments()

    if arguments.subcommand == 'install':
        install(arguments)
    if arguments.subcommand == 'print':
        cross_compile = get_gcc_cross_compile(arguments.version, arguments.arch)
        print(f"CROSS_COMPILE={shlex.quote(cross_compile)}")
