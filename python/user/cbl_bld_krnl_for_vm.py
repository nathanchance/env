#!/usr/bin/env python3

from argparse import ArgumentParser
import os
from pathlib import Path
import platform
import shutil
import subprocess

import requests

import lib_kernel
import lib_user


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


def get_cross_compile(key):
    return {
        'arm': 'arm-linux-gnueabi-',
        'arm64': 'aarch64-linux-',
        'x86_64': 'x86_64-linux-',
    }[key]


def get_toolchain_vars(kernel_arch, toolchain):
    if toolchain == 'llvm':
        return {'LLVM': '1'}

    gcc_version = lib_user.get_latest_gcc_version(int(toolchain.split('-')[1]))

    if not (gcc_folder := Path(os.environ['CBL_TC_STOW_GCC'], gcc_version)).exists():
        raise Exception(f"GCC {gcc_version} not found in {gcc_folder.parent}?")

    cross_compile = get_cross_compile(kernel_arch)
    if not (gcc := Path(gcc_folder, 'bin', f"{cross_compile}gcc")).exists():
        raise Exception(f"{gcc.name} not found in {gcc.parent}?")

    return {'CROSS_COMPILE': Path(gcc.parent, cross_compile)}


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

    parser.add_argument('-m',
                        '--menuconfig',
                        action='store_true',
                        help='Run menuconfig after localyesconfig')

    parser.add_argument('-n',
                        '--vm-name',
                        help='Name of virtual machine to build kernel for',
                        required=True)

    supported_toolchains = [f"gcc-{ver}" for ver in range(6, 13)] + ['llvm']
    parser.add_argument('-t',
                        '--toolchain',
                        choices=supported_toolchains,
                        default='llvm',
                        help='Toolchain to build kernel with')

    parser.add_argument('make_args', nargs='*', help='Arguments to pass to make')

    return parser.parse_args()


def build_kernel_for_vm(make_variables, menuconfig, vm_name):
    subprocess.run(['git', 'cl', '-q'], check=True)
    (build := make_variables['O']).mkdir()

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
            raise Exception(f"{configs.parents[1]} is not downloaded?")
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

    config_src = configs[make_variables['ARCH']]
    config_dst = Path(build, '.config')

    if isinstance(config_src, Path):
        shutil.copyfile(config_src, config_dst)
    elif 'http' in config_src:
        response = requests.get(config_src, timeout=3600)
        response.raise_for_status()
        config_dst.write_bytes(response.content)
    else:
        raise Exception(f"Don't know how to handle {config_src}!")

    make_targets = ['olddefconfig', 'localyesconfig', 'all']
    if menuconfig:
        make_targets.insert(-1, 'menuconfig')
    lib_kernel.kmake(make_variables, make_targets)


if __name__ == '__main__':
    if not Path('Makefile').exists():
        raise Exception('You do not appear to be in a kernel tree?')

    args = parse_arguments()

    arch = get_qemu_arch(args.arch)

    if not (vm_folder := Path(os.environ['VM_FOLDER'], arch, args.vm_name)).exists():
        raise Exception(f"{args.vm_name} not found in {vm_folder.parent}?")

    if not (lsmod := Path(vm_folder, 'shared/kernel_files/lsmod')).exists():
        raise Exception(f"lsmod not found in {vm_folder}?")

    make_vars = {
        'ARCH': qemu_arch_to_kernel_arch(arch),
        'LSMOD': lsmod,
        'O': Path('build'),
    }
    make_vars.update(get_toolchain_vars(make_vars['ARCH'], args.toolchain))
    make_vars.update(dict(arg.split('=', 1) for arg in args.make_args))

    build_kernel_for_vm(make_vars, args.menuconfig, args.vm_name)
