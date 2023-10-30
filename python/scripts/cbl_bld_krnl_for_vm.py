#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

from argparse import ArgumentParser
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

import requests

import korg_gcc

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.kernel  # noqa: E402
# pylint: enable=wrong-import-position


def get_qemu_arch(key):
    return {
        'aarch64': 'aarch64',
        'arm': 'arm',
        'armv7l': 'arm',
        'arm64': 'aarch64',
        'x86_64': 'x86_64',
    }[key]


def qemu_arch_to_kernel_arch(key):
    return {
        'aarch64': 'arm64',
        'arm': 'arm',
        'x86_64': 'x86_64',
    }[key]


def get_toolchain_vars(kernel_arch, toolchain):
    if toolchain == 'llvm':
        return {'LLVM': '1'}

    gcc_major_version = int(toolchain.split('-')[1])
    return {'CROSS_COMPILE': korg_gcc.get_gcc_cross_compile(gcc_major_version, kernel_arch)}


def parse_arguments():
    parser = ArgumentParser(description='Build a kernel suitable for booting in cbl_vmm.py')

    supported_arches = [
        'arm',
        'armv7l',  # to allow using it on armv7l, for some reason?
        'aarch64',
        'arm64',  # to match the kernel, we'll normalize it later
        'x86_64',
    ]
    parser.add_argument('-a',
                        '--arch',
                        choices=supported_arches,
                        default=platform.machine(),
                        help='Architecture to build and boot')

    parser.add_argument(
        '-c',
        '--config',
        help='Use this configuration instead of default configuration for virtual machine')

    parser.add_argument('-m',
                        '--menuconfig',
                        action='store_true',
                        help='Run menuconfig after localyesconfig')

    parser.add_argument('-n',
                        '--vm-name',
                        help='Name of virtual machine to build kernel for',
                        required=True)

    supported_toolchains = [f"gcc-{ver}"
                            for ver in korg_gcc.supported_korg_gcc_versions()] + ['llvm']
    parser.add_argument('-t',
                        '--toolchain',
                        choices=supported_toolchains,
                        default='llvm',
                        help='Toolchain to build kernel with')

    parser.add_argument('--additional-targets',
                        action='append',
                        help="Call target before 'all' target")

    parser.add_argument('make_args', nargs='*', help='Arguments to pass to make')

    return parser.parse_args()


def build_kernel_for_vm(add_make_targets, make_variables, config, menuconfig, vm_name):
    if Path('.config').exists():
        subprocess.run(['git', 'cl', '-q'], check=True)
    if (build := make_variables['O']).exists():
        shutil.rmtree(build)
    build.mkdir(parents=True)

    if 'alpine' in vm_name:
        configs = {
            'arm': 'https://git.alpinelinux.org/aports/plain/main/linux-lts/virt.armv7.config',
            'arm64': 'https://git.alpinelinux.org/aports/plain/main/linux-lts/virt.aarch64.config',
            'x86_64': 'https://git.alpinelinux.org/aports/plain/main/linux-lts/virt.x86_64.config',
        }
    elif 'arch' in vm_name:
        configs = {
            'x86_64': 'https://raw.githubusercontent.com/archlinux/svntogit-packages/packages/linux/trunk/config',
        }  # yapf: disable
    elif 'debian' in vm_name:
        if not (configs := Path(os.environ['CBL_LKT'], 'configs/debian')).exists():
            raise RuntimeError(f"{configs.parents[1]} is not downloaded?")
        configs = {
            'arm': Path(configs, 'armmp.config'),
            'arm64': Path(configs, 'arm64.config'),
            'x86_64': Path(configs, 'amd64.config'),
        }
    elif 'fedora' in vm_name:
        configs = {
            'arm64': 'https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-aarch64-fedora.config',
            'x86_64': 'https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-x86_64-fedora.config',
        }  # yapf: disable

    if config:
        config_src = config if 'http' in config else Path(config)
    else:
        config_src = configs[make_variables['ARCH']]
    config_dst = Path(build, '.config')

    if isinstance(config_src, Path):
        shutil.copyfile(config_src, config_dst)
    elif 'http' in config_src:
        response = requests.get(config_src, timeout=3600)
        response.raise_for_status()
        config_dst.write_bytes(response.content)
    else:
        raise RuntimeError(f"Don't know how to handle {config_src}!")

    make_targets = ['olddefconfig', 'localyesconfig', 'all']
    if menuconfig:
        make_targets.insert(-1, 'menuconfig')
    if add_make_targets:
        for target in add_make_targets:
            make_targets.insert(-1, target)
    lib.kernel.kmake(make_variables, make_targets)


if __name__ == '__main__':
    args = parse_arguments()

    if not Path('Makefile').exists():
        raise RuntimeError('You do not appear to be in a kernel tree?')

    arch = get_qemu_arch(args.arch)

    if not (vm_folder := Path(os.environ['VM_FOLDER'], arch, args.vm_name)).exists():
        raise RuntimeError(f"{args.vm_name} not found in {vm_folder.parent}?")

    if not (lsmod := Path(vm_folder, 'shared/kernel_files/lsmod')).exists():
        raise RuntimeError(f"lsmod not found in {vm_folder}?")

    if 'TMP_BUILD_FOLDER' in os.environ:
        out = Path(os.environ['TMP_BUILD_FOLDER'], Path.cwd().name)
    else:
        out = Path('build')

    make_vars = {
        'ARCH': qemu_arch_to_kernel_arch(arch),
        'LSMOD': lsmod,
        'O': out,
    }
    make_vars.update(get_toolchain_vars(make_vars['ARCH'], args.toolchain))
    make_vars.update(dict(arg.split('=', 1) for arg in args.make_args))

    build_kernel_for_vm(args.additional_targets, make_vars, args.config, args.menuconfig,
                        args.vm_name)
