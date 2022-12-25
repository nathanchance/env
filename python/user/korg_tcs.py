#!/usr/bin/env python3

from argparse import ArgumentParser
import os
from pathlib import Path
import platform
import subprocess

import requests

import lib_kernel
import lib_sha256
import lib_user


def parse_arguments():
    parser = ArgumentParser(description='Easily download and extract kernel.org toolchains to disk')

    supported_arches = lib_kernel.supported_korg_gcc_arches()
    supported_targets = lib_kernel.supported_korg_gcc_targets()
    parser.add_argument('-t',
                        '--targets',
                        choices=supported_arches + supported_targets,
                        default=supported_targets,
                        help='Toolchain targets to download (default: %(default)s)',
                        metavar='TARGETS',
                        nargs='+')

    # GCC 6 through 12
    supported_versions = lib_kernel.supported_korg_gcc_versions()
    parser.add_argument('-v',
                        '--versions',
                        choices=supported_versions,
                        default=supported_versions,
                        help='Toolchain versions to download (default: %(default)s)',
                        metavar='TARGETS',
                        nargs='+',
                        type=int)

    # Download and install locations for toolchains
    download_folder_default = Path(os.environ['NAS_FOLDER'], 'kernel.org/toolchains')
    install_folder_default = Path(os.environ['CBL_TC_STOW_GCC'])
    parser.add_argument('--download-folder',
                        default=download_folder_default,
                        help='Folder to store downloaded tarballs (default: %(default)s)')
    parser.add_argument('--install-folder',
                        default=install_folder_default,
                        help='Folder to store extracted toolchains for use (default: %(default)s)')

    no_group = parser.add_mutually_exclusive_group()
    no_group.add_argument('--no-cache',
                          action='store_true',
                          help='Do not save downloaded toolchain tarballs to disk')
    no_group.add_argument('--no-extract',
                          action='store_true',
                          help='Do not unpack downloaded toolchain tarballs to disk')

    return parser.parse_args()


if __name__ == '__main__':
    args = parse_arguments()
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
        targets = sorted(
            {lib_kernel.korg_gcc_canonicalize_target(target)
             for target in args.targets})
        print(targets)
        # No GCC 9.5.0 i386-linux on x86_64?
        if host_arch == 'x86_64' and major_version == 9:
            targets.remove('i386-linux')
        # RISC-V was not supported in GCC until 7.x
        if major_version < 7:
            targets.remove('riscv32-linux')
            targets.remove('riscv64-linux')

        full_version = lib_user.get_latest_gcc_version(major_version)

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
