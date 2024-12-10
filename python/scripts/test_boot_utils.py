#!/usr/bin/env python3

from argparse import ArgumentParser
import os
from pathlib import Path
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils
# pylint: enable=wrong-import-position

BOOT_QEMU = Path(os.environ['CBL_GIT'], 'boot-utils/boot-qemu.py')

MATRIX = {
    'gcc': {
        'arm32_v5': 'multi_v5_defconfig',
        'arm32_v6': 'aspeed_g5_defconfig',
        'arm32_v7': 'multi_v7_defconfig',
        'arm64': 'defconfig',
        'arm64be': 'defconfig+CONFIG_CPU_BIG_ENDIAN=y',
        'mips': 'malta_defconfig+CONFIG_CPU_BIG_ENDIAN=y',
        'mipsel': 'malta_defconfig',
        'ppc32': 'ppc44x_defconfig',
        'ppc32_mac': 'pmac32_defconfig+CONFIG_SERIAL_PMACZILOG=y+CONFIG_SERIAL_PMACZILOG_CONSOLE=y+CONFIG_SERIAL_PMACZILOG_TTYS=n',
        'ppc64': 'ppc64_guest_defconfig',
        'ppc64le': 'powernv_defconfig',
        'riscv': 'defconfig',
        's390': 'defconfig',
        'x86': 'defconfig',
        'x86_64': 'defconfig',
    },
}  # yapf: disable
MATRIX['clang'] = MATRIX['gcc'].copy()
# https://github.com/ClangBuiltLinux/linux/issues/1814
del MATRIX['clang']['ppc32']

BOOT_UTILS_TO_KERNEL_ROSETTA = {
    'arm32_v5': 'arm',
    'arm32_v6': 'arm',
    'arm32_v7': 'arm',
    'arm64be': 'arm64',
    'mipsel': 'mips',
    'ppc32': 'powerpc',
    'ppc32_mac': 'powerpc',
    'ppc64': 'powerpc',
    'ppc64le': 'powerpc',
    'x86': 'i386',
}

parser = ArgumentParser(description='Test all architectures in boot-utils')
parser.add_argument('directory', help='Directory with results of build-local.py run')
args = parser.parse_args()

if not (directory := Path(args.directory)).exists():
    raise FileNotFoundError(f"Supplied directory ('{directory}') does not exist?")

for toolchain, builds in MATRIX.items():
    for boot_utils_arch, config in builds.items():
        kernel_arch = BOOT_UTILS_TO_KERNEL_ROSETTA.get(boot_utils_arch, boot_utils_arch)

        if not (kernel_dir := Path(directory, toolchain, kernel_arch, config)).exists():
            raise FileNotFoundError(f"{kernel_dir} does not exist?")

        boot_utils_cmd = [BOOT_QEMU, '-a', boot_utils_arch, '-k', kernel_dir, '-t', '90s']
        lib.utils.run(boot_utils_cmd, show_cmd=True)
