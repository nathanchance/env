#!/usr/bin/env python3

from argparse import ArgumentParser
import os
from pathlib import Path
import platform
import shutil
import subprocess

import requests

import lib_user
import lib_sha256


def download_tarballs():
    nas_folder = get_nas_folder()
    if not nas_folder.exists():
        raise Exception(f"{nas_folder} does not exist, setup systemd automount files?")

    toolchains_folder = get_toolchains_folder()
    if not toolchains_folder.exists():
        raise Exception(f"{toolchains_folder} does not exist??")

    for major_version in supported_major_versions():
        gcc_version = get_latest_gcc_version(major_version)

        tarball_folder = toolchains_folder.joinpath(gcc_version)
        tarball_folder.mkdir(exist_ok=True, parents=True)

        for host_arch in ['aarch64', 'x86_64']:
            gcc_host_arch = get_gcc_host_arch(host_arch)
            base_url = f"https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/{gcc_host_arch}/{gcc_version}"
            shasums = f"{base_url}/sha256sums.asc"

            for gcc_target in get_targets(host_arch, major_version):
                tarball = tarball_folder.joinpath(
                    f"{gcc_host_arch}-gcc-{gcc_version}-nolibc-{gcc_target}.tar.xz")
                if tarball.exists():
                    lib_user.print_yellow(f"SKIP: {tarball.name} is already downloaded!")
                else:
                    lib_user.print_green(f"INFO: Downloading {tarball.name}...")
                    response = requests.get(f"{base_url}/{tarball.name}", timeout=3600)
                    response.raise_for_status()
                    tarball.write_bytes(response.content)

                lib_sha256.validate_from_url(tarball, shasums)


def extract_tarballs():
    for major_version in supported_major_versions():
        gcc_version = get_latest_gcc_version(major_version)
        host_arch = get_gcc_host_arch(platform.machine())

        src_folder = get_nas_folder().joinpath('kernel.org', 'toolchains', gcc_version)
        if not src_folder.exists():
            raise Exception(f"{src_folder} does not exist?")

        dst_folder = Path(os.environ['CBL_TC_STOW_GCC'], gcc_version)
        if dst_folder.exists():
            shutil.rmtree(dst_folder)
        dst_folder.mkdir(parents=True)

        for tarball in src_folder.glob(f"{host_arch}-*.tar.xz"):
            tar_cmd = ['tar', '-C', dst_folder, '--strip-components=2', '-xJf', tarball]
            lib_user.print_cmd(tar_cmd)
            subprocess.run(tar_cmd, check=True)


def get_gcc_host_arch(uname_arch):
    return {
        'aarch64': 'arm64',
        'x86_64': 'x86_64',
    }[uname_arch]


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


def get_nas_folder():
    return Path(os.environ['NAS_FOLDER'])


def get_targets(architecture, gcc_version):
    targets = [
        'aarch64-linux',
        'arm-linux-gnueabi',
        'i386-linux',
        'm68k-linux',
        'mips-linux',
        'mips64-linux',
        'powerpc-linux',
        'powerpc64-linux',
        's390-linux',
        'x86_64-linux'
    ]  # yapf: disable

    # No GCC 9.5.0 i386-linux on x86_64?
    if architecture == 'x86_64' and gcc_version == 9:
        targets.remove('i386-linux')

    # RISC-V was not supported in GCC until 7.x
    if gcc_version >= 7:
        targets += ['riscv32-linux', 'riscv64-linux']

    return targets


def get_toolchains_folder():
    return get_nas_folder().joinpath('kernel.org', 'toolchains')


def parse_arguments():
    parser = ArgumentParser()
    subparsers = parser.add_subparsers(help='Action to perform', required=True)

    download_parser = subparsers.add_parser('download',
                                            help='Download kernel.org toolchains to NAS')
    download_parser.set_defaults(func=download_tarballs)

    extract_parser = subparsers.add_parser(
        'extract', help='Extract kernel.org toolchains from NAS to local hard drive')
    extract_parser.set_defaults(func=extract_tarballs)

    return parser.parse_args()


def supported_major_versions():
    return list(range(6, 13))


if __name__ == '__main__':
    args = parse_arguments()
    args.func()
