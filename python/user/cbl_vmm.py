#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor
# Description: Virtual machine manager for ClangBuiltLinux development
# Cobbled together from:
# https://wiki.archlinux.org/title/QEMU
# https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface#Testing_UEFI_in_systems_without_native_support
# https://mirrors.edge.kernel.org/pub/linux/kernel/people/will/docs/qemu/qemu-arm64-howto.html
# https://wiki.qemu.org/Documentation/Networking

from argparse import ArgumentParser
import datetime
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

import lib_user


def can_use_kvm(guest_arch):
    if guest_arch == platform.machine():
        return os.access('/dev/kvm', os.R_OK | os.W_OK)
    return False


def get_base_folder():
    if 'VM_FOLDER' in os.environ:
        return Path(os.environ['VM_FOLDER'])
    return Path(__file__).resolve().parent.joinpath('vm')


def iso_is_url(iso):
    return 'http://' in iso or 'https://' in iso


def run_cmd(cmd):
    lib_user.print_cmd(cmd)
    subprocess.run(cmd, check=True)


def find_in_usr_share(sub_paths):
    for sub_path in sub_paths:
        if (full_path := Path('/usr/share', sub_path)).exists():
            return full_path
    raise Exception(
        f"No subpaths from list ('{', '.join(sub_paths)}') could be found in '/usr/share', do you need to install a package?"
    )


class VirtualMachine:

    def __init__(self, arch, cmdline, cores, gdb, initrd, iso, kernel, memory, name, size,
                 ssh_port):
        # External values
        self.arch = arch
        self.name = name
        self.size = size

        # Internal values
        self.data_folder = get_base_folder().joinpath(self.arch, self.name)
        self.disk_img = self.data_folder.joinpath('disk.img')
        self.efi_img = self.data_folder.joinpath('efi.img')
        self.efi_vars_img = self.data_folder.joinpath('efi_vars.img')

        # QEMU configuration
        self.qemu = 'qemu-system-' + self.arch
        self.qemu_args = [
            # No display
            '-display', 'none',
            '-serial', 'mon:stdio',

            # Disk image
            '-drive', f"if=virtio,format=qcow2,file={self.disk_img}",

            # Networking
            '-nic', f"user,model=virtio-net-pci,hostfwd=tcp::{ssh_port}-:22",

            # RNG
            '-object', 'rng-random,filename=/dev/urandom,id=rng0',
            '-device', 'virtio-rng-pci',

            # Statistics
            '-m', memory,
            '-device', 'virtio-balloon',
            '-smp', str(cores),

            # UEFI
            '-drive', f"if=pflash,format=raw,file={self.efi_img},readonly=on",
            '-drive', f"if=pflash,format=raw,file={self.efi_vars_img}",

            # iso args if setting up machine for the first time
            *self.get_iso_args(iso),
        ]  # yapf: disable
        if can_use_kvm(self.arch):
            self.qemu_args += ['-cpu', 'host', '-enable-kvm']
        if cmdline:
            self.qemu_args += ['-append', cmdline]
        if gdb:
            self.qemu_args += ['-s', '-S']
        if initrd:
            self.qemu_args += ['-initrd', initrd]
        if kernel:
            self.qemu_args += ['-kernel', kernel]

    def handle_action(self, action):
        if action == 'setup':
            return self.setup()
        if action == 'remove':
            return self.remove()
        if action == 'run':
            return self.run()
        raise Exception(f"Unimplemented action ('{action}')?")

    def create_disk_img(self):
        self.disk_img.parent.mkdir(exist_ok=True, parents=True)
        run_cmd(['qemu-img', 'create', '-f', 'qcow2', self.disk_img, self.size])

    def get_iso_args(self, iso):
        if iso is None:
            return []

        # Download iso if necessary
        if iso_is_url(str(iso)):
            iso_url = iso
            iso = get_base_folder().joinpath('iso', iso_url.split('/')[-1])
            if not iso.exists():
                iso.parent.mkdir(exist_ok=True, parents=True)
                run_cmd(['wget', '-c', '-O', iso, iso_url])

        if not iso.exists():
            raise Exception(
                f"{iso.name} does not exist at {iso}, was the wrong path used or did the download fail?"
            )

        return [
            '-device', 'virtio-scsi-pci,id=scsi0',
            '-device', 'scsi-cd,drive=cd',
            '-drive', f"if=none,format=raw,id=cd,file={iso}"
        ]  # yapf: disable

    def remove(self):
        if self.data_folder.is_dir():
            shutil.rmtree(self.data_folder)

    def run(self):
        if not shutil.which(self.qemu):
            raise Exception(
                f"Could not find QEMU ('{self.qemu}') on your system, install it first?")
        if not self.disk_img.exists():
            raise Exception(f"Disk image ('{self.disk_img}') does not exist, run 'setup' first?")
        run_cmd([self.qemu, *self.qemu_args])

    def setup(self):
        self.remove()
        self.create_disk_img()
        self.run()


class Arm64VirtualMachine(VirtualMachine):

    def __init__(self, cmdline, cores, gdb, initrd, iso, kernel, memory, name, size, ssh_port):
        super().__init__('aarch64', cmdline, cores, gdb, initrd, iso, kernel, memory, name, size,
                         ssh_port)

        self.qemu_args += ['-M', 'virt']

        # If not running on KVM, use QEMU's max CPU emulation target
        # Use impdef pointer auth, otherwise QEMU is just BRUTALLY slow:
        # https://lore.kernel.org/YlgVa+AP0g4IYvzN@lakrids/
        if '-cpu' not in self.qemu_args:
            self.qemu_args += ['-cpu', 'max,pauth-impdef=true']

    def run(self):
        self.setup_efi_files()
        super().run()

    def setup_efi_files(self):
        efi_img_size = 64 * 1024 * 1024  # 64M

        self.efi_img.parent.mkdir(exist_ok=True, parents=True)

        if not self.efi_img.exists():
            possible_paths = [
                Path('edk2/aarch64/QEMU_EFI.silent.fd'),  # Fedora
                Path('edk2/aarch64/QEMU_EFI.fd'),  # Arch Linux (current)
                Path('edk2-armvirt/aarch64/QEMU_EFI.fd'),  # Arch Linux (old),
                Path("qemu-efi-aarch64/QEMU_EFI.fd"),  # Debian and Ubuntu
            ]
            shutil.copyfile(find_in_usr_share(possible_paths), self.efi_img)
            self.efi_img.open(mode='r+b').truncate(efi_img_size)

        if not self.efi_vars_img.exists():
            self.efi_vars_img.open(mode='xb').truncate(efi_img_size)


class X86VirtualMachine(VirtualMachine):

    def __init__(self, cmdline, cores, gdb, initrd, iso, kernel, memory, name, size, ssh_port):
        super().__init__('x86_64', cmdline, cores, gdb, initrd, iso, kernel, memory, name, size,
                         ssh_port)

    def run(self):
        self.setup_efi_files()
        super().run()

    def setup_efi_files(self):
        self.efi_img.parent.mkdir(exist_ok=True, parents=True)

        if not self.efi_img.exists():
            possible_paths = [
                Path('edk2/x64/OVMF_CODE.fd'),  # Arch Linux (current), Fedora
                Path('edk2-ovmf/x64/OVMF_CODE.fd'),  # Arch Linux (old)
                Path("OVMF/OVMF_CODE.fd"),  # Debian and Ubuntu
            ]
            shutil.copyfile(find_in_usr_share(possible_paths), self.efi_img)

        if not self.efi_vars_img.exists():
            possible_paths = [
                Path("edk2/x64/OVMF_VARS.fd"),  # Arch Linux and Fedora
                Path("OVMF/OVMF_VARS.fd"),  # Debian and Ubuntu
            ]
            shutil.copyfile(find_in_usr_share(possible_paths), self.efi_vars_img)


def parse_arguments():
    parser = ArgumentParser()
    subparsers = parser.add_subparsers(help='Action to perform', required=True)

    # Common arguments for all subcommands
    common_parser = ArgumentParser(add_help=False)
    common_parser.add_argument('-a',
                               '--architecture',
                               type=str,
                               default=platform.machine(),
                               help='Architecture of virtual machine')
    common_parser.add_argument('-c',
                               '--cores',
                               type=int,
                               help='Number of cores virtual machine has')
    common_parser.add_argument('-m',
                               '--memory',
                               type=str,
                               help='Amount of memory virtual machine has')
    common_parser.add_argument('-n', '--name', type=str, help='Name of virtual machine')
    common_parser.add_argument('-p',
                               '--ssh-port',
                               default=8022,
                               type=int,
                               help='Port to forward ssh on')

    # Arguments for "list"
    list_parser = subparsers.add_parser('list',
                                        help='List virtual machines that can be run',
                                        parents=[common_parser])
    list_parser.set_defaults(action='list')

    # Arguments for "setup"
    setup_parser = subparsers.add_parser('setup',
                                         help='Run virtual machine for first time',
                                         parents=[common_parser])
    setup_parser.add_argument('-i', '--iso', type=str, help='Path or URL of .iso to boot from')
    setup_parser.add_argument('-s',
                              '--size',
                              type=str,
                              default='50G',
                              help='Size of virtual machine disk image')
    setup_parser.set_defaults(action='setup')

    # Arguments for "remove"
    remove_parser = subparsers.add_parser('remove',
                                          help='Remove virtual machine files',
                                          parents=[common_parser])
    remove_parser.set_defaults(action='remove')

    # Arguments for "run"
    run_parser = subparsers.add_parser('run',
                                       help='Run virtual machine after setup',
                                       parents=[common_parser])
    run_parser.add_argument('-C', '--cmdline', type=str, help='Kernel cmdline string')
    run_parser.add_argument('-g',
                            '--gdb',
                            action='store_true',
                            help="Start QEMU with '-s -S' for debugging with gdb")
    run_parser.add_argument('-i', '--initrd', type=str, help='Path to initrd')
    run_parser.add_argument('-k',
                            '--kernel',
                            type=str,
                            help='Path to kernel image or kernel build directory')
    run_parser.set_defaults(action='run')

    return parser.parse_args()


# We consider half of the system's memory in gigabytes as available for the
# virtual machine
def get_available_mem_for_vm():
    # Total amount of memory of a system in gigabytes (page size * pages / 1024^3)
    total_mem = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') / (1024.**3)

    # Get the current exponent of the size of memory, as most computers have a
    # power of 2 amount of memory; if it is not (like 12GB), then this
    # calculation will just result in a slightly larger amount of memory being
    # allocated to the VM. If this is a problem, the user can just specify the
    # amount of memory.
    exp = round(math.log2(total_mem))

    # To get half of the amount of memory, shift by one less exponent
    return 1 << (exp - 1)


def get_def_iso(arch):
    arch_day = '.01'
    arch_iso_ver = datetime.datetime.now(datetime.timezone.utc).strftime("%Y.%m") + arch_day

    fedora_ver = '37'
    fedora_iso_ver = '1.7'

    iso_info = {
        'aarch64': {
            'file': Path('Fedora', fedora_ver, 'Server', f"Fedora-Server-netinst-{arch}-{fedora_ver}-{fedora_iso_ver}.iso"),
            'url': f"https://download.fedoraproject.org/pub/fedora/linux/releases/{fedora_ver}/Server/{arch}",
        },
        'x86_64': {
            'file': Path('Arch Linux', f"archlinux-{arch_iso_ver}-x86_64.iso"),
            'url': 'https://mirrors.edge.kernel.org/archlinux/iso/',
        },
    }  # yapf: disable

    # Check to see if we have a local network version we can use
    file = iso_info[arch]['file']
    if 'NAS_FOLDER' in os.environ:
        if (iso := Path(os.environ['NAS_FOLDER'], 'Firmware_and_Images', file)).exists():
            return iso

    # Otherwise, return the URL so that it can be fetched and cached on the
    # machine
    return f"{iso_info[arch]['url']}/{file.name}"


# We cap the default amount of memory at two times the number of cores (as that
# is sufficient for compiling) or total amount of available VM memory.
def get_def_mem(cores):
    return f"{int(min(cores * 2, get_available_mem_for_vm()))}G"


def create_vm_from_args(args):
    # Simple configuration section with short one liners with no logic. Either
    # it came from argparse (meaning the default was able to be set there or
    # the user customized it) or we use a default from the dictionary below.
    # Some options are dynamically calculated using the functions above.
    # hasattr() is used to check if the option exists within argparse, as
    # certain flags are only available for certain modes.
    arch = args.architecture
    static_defaults = {
        'aarch64': {
            'initrd': Path('initramfs.img'),
            'kernel': Path('arch/arm64/boot/Image'),
            'name': 'fedora',
        },
        'x86_64': {
            'initrd': Path('rootfs/initramfs.img'),
            'kernel': Path('arch/x86/boot/bzImage'),
            'name': 'arch',
        },
        # When using KVM, we cannot use more than the maximum number of cores.
        # Default to either 8 cores or half the number of cores in the
        # machine, whichever is smaller. For TCG, use 4 cores by default.
        'cores': min(8, int(os.cpu_count() / 2)) if can_use_kvm(arch) else 4,
        'iso': get_def_iso(arch),
    }
    cores = args.cores if args.cores else static_defaults['cores']
    gdb = args.gdb if hasattr(args, 'gdb') else False
    # The amount of default memory depends on the actual amount of cores, not
    # the default.
    memory = args.memory if args.memory else get_def_mem(cores)
    name = args.name if args.name else static_defaults[arch]['name']
    size = args.size if hasattr(args, 'size') else None
    ssh_port = args.ssh_port

    # Default .iso
    # Check if iso is even in the current args, as it is only required for
    # 'setup'. If the user supplied one, check if it is a url; if not, it has
    # to be a path. If the user did not supply an iso, get the default one.
    iso = None
    if hasattr(args, 'iso'):
        if args.iso:
            if iso_is_url(args.iso):
                iso = args.iso
            else:
                iso = Path(args.iso)
        else:
            iso = get_def_iso(arch)

    # Support for running custom kernel image (only available when actually
    # running a machine). More windy logic due to implicit defaults.
    cmdline = None
    initrd = None
    kernel = None
    if hasattr(args, 'kernel') and args.kernel:
        # Figure out whether kernel argument is build folder or kernel image
        if (kernel_obj := Path(args.kernel)).is_dir():
            kernel_folder = kernel_obj
            kernel_img = kernel_folder.joinpath(static_defaults[arch]['kernel'])
        else:
            kernel_folder = None
            kernel_img = kernel_obj
        if not kernel_img.exists():
            raise Exception(
                f"Kernel image ('{kernel_img}'), derived from kernel argument ('{args.kernel}'), does not exist!"
            )

        # Handle command line; no default as it is specific to the VM
        if args.cmdline:
            cmdline = args.cmdline

        # Handle initial ramdisk
        if args.initrd:
            initrd = Path(args.initrd)
        else:
            if not kernel_folder:
                raise Exception('Full kernel image supplied without initrd path!')
            initrd = kernel_folder.joinpath(static_defaults[arch]['initrd'])
        if not initrd.exists():
            raise Exception(
                f"Initial ramdisk ('{initrd}'), derived from initrd argument ('{args.initrd}'), does not exist!"
            )

    # Create the VirtualMachine object for the particular architecture.
    if arch == 'aarch64':
        return Arm64VirtualMachine(cmdline, cores, gdb, initrd, iso, kernel, memory, name, size,
                                   ssh_port)
    if arch == 'x86_64':
        return X86VirtualMachine(cmdline, cores, gdb, initrd, iso, kernel, memory, name, size,
                                 ssh_port)
    raise Exception(f"Unimplemented architecture ('{arch}')?")


def list_vms(arch):
    print(f"\nAvailable virtual machines for {arch}:\n")

    if (arch_folder := get_base_folder().joinpath(arch)).exists():
        vms = sorted([elem.name for elem in arch_folder.iterdir() if elem.is_dir()])
        if vms:
            print('\n'.join(vms))
            return

    print('None')


if __name__ == '__main__':
    # Get arguments
    arguments = parse_arguments()

    if arguments.action == 'list':
        list_vms(arguments.architecture)
        sys.exit(0)

    create_vm_from_args(arguments).handle_action(arguments.action)
