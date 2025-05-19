#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

from argparse import ArgumentParser, BooleanOptionalAction
import os
from pathlib import Path
import platform
import shlex
import shutil
import sys

import requests

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.sha256
import lib.utils
# pylint: enable=wrong-import-position

LATEST_GCC_VERSIONS = {
    14: '14.2.0',
    13: '13.3.0',
    12: '12.4.0',
    11: '11.5.0',
    10: '10.5.0',
    9: '9.5.0',
    8: '8.5.0',
    7: '7.5.0',
    6: '6.5.0',
    5: '5.5.0',
}
LATEST_LLVM_VERSIONS = {
    20: '20.1.5',
    19: '19.1.7',
    18: '18.1.8',
    17: '17.0.6',
    16: '16.0.6',
    15: '15.0.7',
    14: '14.0.6',
    13: '13.0.1',
    12: '12.0.1',
    11: '11.1.0',
}


# set() does not preserve order
def dedup(iterable):
    return list(dict.fromkeys(iterable))


def generate_versions(min_var, tot_var):
    return list(range(int(os.environ[min_var]), int(os.environ[tot_var])))


def handle_rc_version(version):
    major, minor, patch = version.split('.')
    if '-' in patch:  # -rc version
        patch, rc = patch.split('-')
        rc = rc.replace('rc', '')
    else:
        rc = '99'  # make sure release versions outrank RC versions
    return tuple(map(int, (major, minor, patch, rc)))


def shell_quote(item):
    return shlex.quote(str(item))


class Tarball:

    def __init__(self):
        self.base_download_url = ''
        self.extraction_location = None
        self.extracted_file = None
        self.local_location = None
        self.remote_tarball_name = ''
        self.remote_checksum_name = ''
        self.strip_components = 1

    def handle(self):
        if not self.extracted_file:
            raise RuntimeError('No extracted file to test for tarball?')
        if not self.local_location:
            raise RuntimeError('No local location configured for tarball?')

        if self.extracted_file.exists() and not self.remote_checksum_name:
            lib.utils.print_green(f"SKIP: Content of {self.remote_tarball_name} exists locally...")
            return

        local_tarball = Path(self.local_location, self.remote_tarball_name)
        if not local_tarball.exists():
            lib.utils.print_green(f"INFO: Downloading {local_tarball.name}...")

            response = requests.get(f"{self.base_download_url}/{local_tarball.name}", timeout=3600)
            response.raise_for_status()

            if self.remote_checksum_name:
                local_tarball.parent.mkdir(exist_ok=True, parents=True)
                local_tarball.write_bytes(response.content)
                lib.sha256.validate_from_url(
                    local_tarball, f"{self.base_download_url}/{self.remote_checksum_name}")

        if self.extraction_location and not self.extracted_file.exists():
            self.extraction_location.mkdir(exist_ok=True, parents=True)

            tar_cmd = [
                'tar',
                '-C', self.extraction_location,
                f"--strip-components={self.strip_components}",
                '-x',
                '-f', local_tarball if local_tarball.exists() else '-',
            ]  # yapf: disable

            comp_ext = local_tarball.suffix
            if comp_ext == '.xz':
                tar_cmd.append('-J')
            elif comp_ext == '.zst':
                tar_cmd.append('--zstd')
            elif comp_ext != '.tar':
                raise RuntimeError(f"Compression extension ('{comp_ext}') not supported!")

            tar_input = response.content if not local_tarball.exists() else None
            lib.utils.run(tar_cmd, input=tar_input, show_cmd=True)


class ToolchainManager:

    def __init__(self):
        self.download_folder = None
        self.install_folder = None

        self.host_arch = platform.machine()

        self.targets = []

        self.latest_versions = {}
        self.versions = []

    def clean_up_old_versions(self):
        if not self.latest_versions:
            raise RuntimeError('Attempting to call clean_up_old_versions() without latest version?')
        if not self.versions:
            raise RuntimeError('Attempting to call clean_up_old_versions() with no versions?')

        for version in self.versions:
            latest_version = handle_rc_version(self.latest_versions[version])

            for install_prefix in self.install_folder.glob(f"{version}.*"):
                # tip of tree builds have more than one hyphen, ignore them
                # when cleaning up old versions
                if install_prefix.name.count('-') > 1:
                    continue

                found_version = handle_rc_version(install_prefix.name)
                if found_version < latest_version:
                    lib.utils.print_green(f"INFO: Removing {install_prefix.name}...")
                    shutil.rmtree(install_prefix)

    def print_latest_versions(self):
        if not self.latest_versions:
            print('Attempting to call print_latest_versions() without latest version?')
        if not self.versions:
            print('Attempting to call print_latest_versions() with no versions?')

        for version in self.versions:
            if version in self.latest_versions:
                print(self.latest_versions[version])


class GCCManager(ToolchainManager):

    DEFAULT_DOWNLOAD_FOLDER = Path(os.environ['NAS_FOLDER'], 'Toolchains/GCC')
    DEFAULT_INSTALL_FOLDER = Path(os.environ['CBL_TC_GCC_STORE'])

    TARGETS = (
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
        'sparc',  # accept kernel value for sparc64
        'sparc64',
        'x86_64',
    )

    VERSIONS = generate_versions('GCC_VERSION_MIN_KERNEL', 'GCC_VERSION_TOT')

    def __init__(self):
        super().__init__()

        self.latest_versions = LATEST_GCC_VERSIONS

    def canonicalize_target(self, value):
        if 'linux' in value:
            return value

        suffix = '-gnueabi' if value == 'arm' else ''

        # in case the kernel ARCH value is passed in, we make an educated guess as
        # to what the user intended
        kernel_to_gcc = {
            'arm64': 'aarch64',
            'loongarch': 'loongarch64',
            'riscv': 'riscv64',
            'sparc': 'sparc64',
        }
        return f"{kernel_to_gcc.get(value, value)}-linux{suffix}"

    def get_cc_as_path(self, version, target):
        full_version = LATEST_GCC_VERSIONS[version]
        canonical_target = self.canonicalize_target(target)

        return Path(os.environ['CBL_TC_GCC_STORE'], full_version, f"bin/{canonical_target}-")

    def install(self, cache, extract):
        if not self.download_folder:
            raise RuntimeError('Attempting to call install() with no download folder?')
        if not self.install_folder:
            raise RuntimeError('Attempting to call install() with no install folder?')
        if cache and not self.download_folder.exists():
            raise RuntimeError(
                f"Download folder ('{self.download_folder}') does not exist, please create it before running this script!",
            )

        host_arch_gcc = {
            'aarch64': 'arm64',
            'x86_64': 'x86_64',
        }[self.host_arch]

        for major_version in self.versions:
            targets = sorted({self.canonicalize_target(val) for val in self.targets})

            # No GCC 5.5.0 aarch64-linux on aarch64?
            if self.host_arch == 'aarch64' and 'aarch64-linux' in targets and major_version == 5:
                targets.remove('aarch64-linux')
            # Ensure 'arm' gets downloaded with 'aarch64', so that compat vDSO can
            # be built.
            if 'aarch64-linux' in targets:
                targets.append('arm-linux-gnueabi')
            # No GCC 9.5.0 i386-linux on x86_64 or GCC 14.2.0 i386-linux on aarch64?
            if 'i386-linux' in targets and (self.host_arch, major_version) in (('x86_64', 9),
                                                                               ('aarch64', 14)):
                targets.remove('i386-linux')
            # RISC-V was not supported in GCC until 7.x
            if major_version < 7:
                for bits in ['32', '64']:
                    if (rv_target := f"riscv{bits}-linux") in targets:
                        targets.remove(rv_target)
            # LoongArch was not supported in GCC until 12.x
            if major_version < 12 and 'loongarch64-linux' in targets:
                targets.remove('loongarch64-linux')

            full_version = self.latest_versions[major_version]

            for target in targets:
                tarball = Tarball()

                tarball.strip_components = 2

                tarball.base_download_url = f"https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/{host_arch_gcc}/{full_version}"
                tarball.remote_tarball_name = f"{host_arch_gcc}-gcc-{full_version}-nolibc-{target}.tar.xz"

                tarball.local_location = Path(self.download_folder, full_version)
                extraction_location = Path(self.install_folder, full_version)
                tarball.extracted_file = Path(extraction_location, f"bin/{target}-gcc")

                if extract:
                    tarball.extraction_location = extraction_location

                if cache:
                    tarball.remote_checksum_name = 'sha256sums.asc'

                tarball.handle()

    def print_folder(self, folder):
        if len(self.versions) != 1:
            raise RuntimeError('Asking for print_folder() with number of versions other than one?')

        # Architecture does not matter because it will not be printed
        cc = self.get_cc_as_path(self.versions[0], 'x86_64')

        if folder not in ('bin', 'prefix'):
            raise ValueError(f"Do not know how to handle {folder} in print_folder()?")

        print(shell_quote(cc.parents[1 if folder == 'prefix' else 0]))

    def print_vars(self, split):
        if len(self.targets) != 1:
            raise RuntimeError('Asking for print_vars() other than with one target architecture?')
        if len(self.versions) != 1:
            raise RuntimeError('Asking for print_vars() other than with one version?')

        cc_path = self.get_cc_as_path(self.versions[0], self.targets[0])

        cc_args = []
        cc_vars = {}

        if split:
            cc_args += ['-p', shell_quote(cc_path.parent)]
            cc_path = cc_path.name
        cc_vars['CROSS_COMPILE'] = shell_quote(cc_path)

        # Ensure compat vDSO gets built for all arm64 compiles
        if self.targets[0] in ('aarch64', 'arm64'):
            compat_cc = self.get_cc_as_path(self.versions[0], 'arm')
            if split:
                compat_cc = compat_cc.name
            cc_vars['CROSS_COMPILE_COMPAT'] = shell_quote(compat_cc)

        cc_args += [f"{key}={val}" for key, val in cc_vars.items()]

        for arg in cc_args:
            print(arg)


class LLVMManager(ToolchainManager):

    DEFAULT_DOWNLOAD_FOLDER = Path(os.environ['NAS_FOLDER'], 'Toolchains/LLVM')
    DEFAULT_INSTALL_FOLDER = Path(os.environ['CBL_TC_LLVM_STORE'])

    VERSIONS = generate_versions('LLVM_VERSION_MIN_KERNEL', 'LLVM_VERSION_TOT')

    def __init__(self):
        super().__init__()

        self.latest_versions = LATEST_LLVM_VERSIONS

    def get_prefix(self, version=None):
        if not version:
            if len(self.versions) != 1:
                raise RuntimeError('Asking for print_vars() other than with one version?')
            version = self.versions[0]

        return Path(self.DEFAULT_INSTALL_FOLDER, LATEST_LLVM_VERSIONS[version])

    # pylint: disable-next=unused-argument
    def install(self, cache, extract):  # noqa: ARG002
        if not self.download_folder:
            raise RuntimeError('Attempting to call install() with no download folder?')
        if not self.install_folder:
            raise RuntimeError('Attempting to call install() with no install folder?')

        for major_version in self.versions:
            full_version = self.latest_versions[major_version]

            tarball = Tarball()
            tarball.local_location = self.download_folder
            tarball.remote_tarball_name = f"llvm-{full_version}-{self.host_arch}.tar.zst"

            if not Path(tarball.local_location, tarball.remote_tarball_name).exists():
                tarball.base_download_url = 'https://mirrors.edge.kernel.org/pub/tools/llvm/files/'
                tarball.remote_tarball_name = tarball.remote_tarball_name.replace(
                    '.tar.zst', '.tar.xz')

            extraction_location = Path(self.install_folder, full_version)
            tarball.extracted_file = Path(extraction_location, 'bin/clang')
            tarball.extraction_location = extraction_location

            tarball.handle()

    def print_folder(self, folder):
        if len(self.versions) != 1:
            raise RuntimeError('Asking for print_folder() with number of versions other than one?')

        if folder not in ('bin', 'prefix'):
            raise ValueError(f"Do not know how to handle {folder} in print_folder()?")

        prefix = self.get_prefix(self.versions[0])

        print(shell_quote(Path(prefix, 'bin') if folder == 'bin' else prefix))

    def print_vars(self, split):
        if len(self.versions) != 1:
            raise RuntimeError('Asking for print_vars() other than with one version?')

        llvm_ver = LATEST_LLVM_VERSIONS[self.versions[0]]
        llvm_bin = Path(self.DEFAULT_INSTALL_FOLDER, llvm_ver, 'bin')

        cc_args = []
        cc_vars = {}

        if split:
            cc_args = ['-p', shell_quote(llvm_bin)]
            cc_vars['LLVM'] = 1
        else:
            cc_vars['LLVM'] = shell_quote(f"{llvm_bin}/")

        cc_args += [f"{key}={val}" for key, val in cc_vars.items()]

        for arg in cc_args:
            print(arg)


if __name__ == '__main__':
    if (prog := sys.argv[0].rsplit('/', 1)[1]).startswith('korg_gcc'):
        manager = GCCManager()
    elif prog.startswith('korg_llvm'):
        manager = LLVMManager()
    else:
        acceptable_progs = ('korg_gcc', 'korg_gcc.py', 'korg_llvm', 'korg_llvm.py')
        raise RuntimeError(
            f"{prog} needs to be symlinked to either {' or '.join(acceptable_progs)} to function properly!",
        )

    supported_versions = manager.VERSIONS
    supported_targets = getattr(manager, 'TARGETS', None)

    parser = ArgumentParser()
    subparser = parser.add_subparsers(dest='subcommand', metavar='SUBCOMMAND', required=True)

    install_parser = subparser.add_parser(
        'install', help='Download and/or extact kernel.org GCC tarballs to disk')
    install_parser.add_argument('-c',
                                '--clean-up-old-versions',
                                action='store_true',
                                help='Clean up older version of toolchains')
    install_parser.add_argument(
        '-H',
        '--host-arch',
        choices=['aarch64', 'x86_64'],
        default=platform.machine(),
        help='The host architecture to download/install toolchains for (default: %(default)s)',
        metavar='HOST_ARCH')
    if supported_targets:
        install_parser.add_argument('-t',
                                    '--targets',
                                    choices=supported_targets,
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

    install_parser.add_argument('--download-folder',
                                default=manager.DEFAULT_DOWNLOAD_FOLDER,
                                help='Folder to store downloaded tarballs (default: %(default)s)',
                                type=Path)
    install_parser.add_argument(
        '--install-folder',
        default=manager.DEFAULT_INSTALL_FOLDER,
        help='Folder to store extracted toolchains for use (default: %(default)s)',
        type=Path)
    install_parser.add_argument(
        '--cache',
        action=BooleanOptionalAction,
        default=Path(os.environ['NAS_FOLDER']).exists(),
        help='Save downloaded toolchain tarballs to disk (default: %(default)s)')
    install_parser.add_argument(
        '--extract',
        action=BooleanOptionalAction,
        default=True,
        help='Unpack downloaded toolchain tarballs to disk (default: %(default)s)')

    latest_parser = subparser.add_parser(
        'latest', help='Print the latest stable release of a particular toolchain major version')
    latest_parser.add_argument('versions', choices=supported_versions, nargs='+', type=int)

    folder_parser = subparser.add_parser(
        'folder', help='Print toolchain folder values for use in other contexts')
    folder_type = folder_parser.add_mutually_exclusive_group(required=True)
    folder_type.add_argument('-b',
                             '--bin',
                             action='store_const',
                             const='bin',
                             dest='folder',
                             help='Print {prefix}/bin')
    folder_type.add_argument('-p',
                             '--prefix',
                             action='store_const',
                             const='prefix',
                             dest='folder',
                             help='Print {prefix}')
    folder_parser.add_argument('version',
                               choices=supported_versions,
                               default=manager.VERSIONS[-1],
                               nargs='?',
                               type=int)

    var_parser = subparser.add_parser('var', help='Print toolchain variable for use with make')
    var_parser.add_argument('-s',
                            '--split',
                            action='store_true',
                            help='Split toolchain variable for use with kmake.py')
    if supported_targets:
        target_kwargs = {}
        if (mach := platform.machine()) in supported_targets:
            target_kwargs['default'] = mach
            target_kwargs['nargs'] = '?'
        var_parser.add_argument('target', choices=supported_targets, **target_kwargs)
    var_parser.add_argument('version',
                            choices=supported_versions,
                            default=manager.VERSIONS[-1],
                            nargs='?',
                            type=int)

    args = parser.parse_args()

    if hasattr(args, 'target'):
        manager.targets.append(args.target)
    if hasattr(args, 'targets'):
        manager.targets = dedup(args.targets)
    if hasattr(args, 'version'):
        manager.versions.append(args.version)
    if hasattr(args, 'versions'):
        manager.versions = dedup(args.versions)

    if args.subcommand == 'install':
        if not args.cache and not args.extract:
            lib.utils.print_red('ERR: --no-cache and --no-extract used together?')
            sys.exit(128)

        manager.download_folder = args.download_folder.resolve()
        manager.host_arch = args.host_arch
        manager.install_folder = args.install_folder.resolve()

        manager.install(args.cache, args.extract)
        if args.clean_up_old_versions:
            manager.clean_up_old_versions()

    if args.subcommand == 'folder':
        manager.print_folder(args.folder)

    if args.subcommand == 'latest':
        manager.print_latest_versions()

    if args.subcommand == 'var':
        manager.print_vars(args.split)
