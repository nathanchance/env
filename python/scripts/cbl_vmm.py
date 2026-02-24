#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor
# Description: Virtual machine manager for ClangBuiltLinux development
# Cobbled together from:
# https://wiki.archlinux.org/title/QEMU
# https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface#Testing_UEFI_in_systems_without_native_support
# https://mirrors.edge.kernel.org/pub/linux/kernel/people/will/docs/qemu/qemu-arm64-howto.html
# https://wiki.qemu.org/Documentation/Networking

import grp
import json
import math
import os
import platform
import shutil
import subprocess
import sys
import time
from argparse import ArgumentParser
from pathlib import Path
from tempfile import TemporaryDirectory

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils

# pylint: enable=wrong-import-position

# Static constants
BASE_FOLDER = Path(os.environ['VM_FOLDER']) if 'VM_FOLDER' in os.environ else Path(
    __file__).resolve().parent.joinpath('vm')
DEFAULT_DISTRO = {
    'aarch64': 'fedora',
    'arm64': 'fedora',
    'arm': 'debian',
    'x86_64': 'arch',
}
DEFAULT_KERNEL_PATH = {
    'aarch64': Path('arch/arm64/boot/Image'),
    'arm': Path('arch/arm/boot/zImage'),
    'i386': Path('arch/x86/boot/bzImage'),
    'x86_64': Path('arch/x86/boot/bzImage'),
}
DEV_KVM_ACCESS = os.access('/dev/kvm', os.R_OK | os.W_OK)
HOST_ARCH = platform.machine()


def find_first_file(possible_files):
    for file in possible_files:
        if file.exists():
            return file
    files_str = "', '".join(str(elem) for elem in possible_files)
    raise RuntimeError(
        f"No items from list ('{files_str}') could be found, do you need to install a package?")


class VirtualMachine:

    def __init__(self, arch, name):
        # External values (required explicitly for _data_folder assignment below)
        self.arch = arch
        self.name = name

        # Internal values
        self._data_folder = Path(BASE_FOLDER, self.arch, self.name)
        self._efi_img = Path(self._data_folder, 'efi.img')
        self._efi_vars_img = Path(self._data_folder, 'efi_vars.img')
        self._images_to_mount = (x for x in Path(self._data_folder).glob('*.img')
                                 if 'efi' not in x.name)
        self._primary_disk_img = Path(self._data_folder, 'disk.img')
        self._qemu = 'qemu-system-' + self.arch
        self._shared_folder = Path(self._data_folder, 'shared')
        # This is good enough for most cases
        self._use_kvm = self.arch == HOST_ARCH and DEV_KVM_ACCESS
        self._kvm_cpu = 'host'

        # External values (can be calculated implicitly currently or later)
        self.cmdline = ''
        self.cores = 0
        self.initrd = None
        self.iso = None
        self.kernel = None
        self.memory = 0
        self.profile = 'regular'
        # At this stage, only completely static arguments should be added!
        self.qemu_args = [
            # RNG
            '-object', 'rng-random,filename=/dev/urandom,id=rng0',
            '-device', 'virtio-rng-pci',

            # Shared folder via virtiofs (socket is added transiently below)
            '-device', 'vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=host',
            '-numa', 'node,memdev=mem',

            # Statistics
            '-device', 'virtio-balloon',

            # UEFI
            '-drive', f"if=pflash,format=raw,file={self._efi_img},readonly=on",
            '-drive', f"if=pflash,format=raw,file={self._efi_vars_img}",
        ]  # yapf: disable
        self.size = 75
        self.ssh_port = 8022

    def _calc_cpus(self):
        # Respect the user's choice of number of cores
        if self.cores:
            return self.cores

        # If we are not using KVM (i.e., using TCG), use 4 cores by default
        if not self._use_kvm:
            return 4

        # If we are using KVM and we are using the regular profile, we default to 8 CPUs or half the number of CPUs, whichever is smaller
        half_num_cpus = int(os.cpu_count() / 2)
        if self.profile == 'regular':
            return min(8, half_num_cpus)

        # If we are using KVM and we are using the build profile, we default to half the number of CPUs
        if self.profile == 'build':
            return half_num_cpus

        raise RuntimeError('Did not return in _calc_cpus()?')

    def _calc_mem(self, cpus):
        # Respect the user's choice of memory
        if self.memory:
            return self.memory

        # Total amount of memory of a system in gigabytes (page size * pages / 1024^3)
        total_mem = os.sysconf('SC_PAGE_SIZE') * os.sysconf('SC_PHYS_PAGES') / (1024.**3)

        # Get the current exponent of the size of memory, as most computers have a
        # power of 2 amount of memory; if it is not (like 12GB), then this
        # calculation will just result in a slightly larger amount of memory being
        # allocated to the VM. If this is a problem, the user can just specify the
        # amount of memory.
        exp = round(math.log2(total_mem))

        # To get half of the amount of memory, shift by one less exponent
        avail_mem = 1 << (exp - 1)

        # We cap the default amount of memory at two times the number of cores
        # (as that is sufficient for compiling) or total amount of available VM
        # memory.
        return min(cpus * 2, avail_mem)

    def _create_disk_img(self):
        self._primary_disk_img.parent.mkdir(exist_ok=True, parents=True)
        lib.utils.run(
            ['qemu-img', 'create', '-f', 'qcow2', self._primary_disk_img, f"{self.size}G"],
            show_cmd=True)

    def _gen_dynamic_qemu_args(self):
        cpu_val = self._calc_cpus()
        mem_val = f"{self._calc_mem(cpu_val)}G"

        args = [
            # Memory
            '-m', mem_val,

            # Networking
            '-nic', f"user,model=virtio-net-pci,hostfwd=tcp::{self.ssh_port}-:22",

            # Remaining virtiofs argument
            '-object', f"memory-backend-memfd,id=mem,share=on,size={mem_val}",

            # Number of CPUs
            '-smp', str(cpu_val),
        ]  # yapf: disable
        # If we are not already running graphically, display the serial console output
        if '-display' not in self.qemu_args:
            args += ['-display', 'none', '-serial', 'mon:stdio']

        # Attempt to locate static kernel files if only a kernel was passed
        if self.kernel:
            args += ['-kernel', self.kernel]

            kernel_files = Path(self._shared_folder, 'kernel_files')

            if not (cmdline := self.cmdline):
                if not (cmdline_file := Path(kernel_files, 'cmdline')).exists():
                    raise RuntimeError('kernel passed without cmdline and one could not be found!')
                cmdline = cmdline_file.read_text(encoding='utf-8').strip()
            args += ['-append', cmdline]

            if not (initrd := self.initrd) and not (initrd := Path(kernel_files,
                                                                   'initramfs')).exists():
                raise RuntimeError('kernel passed without initrd and one could not be found!')
            args += ['-initrd', initrd]

        # ISO
        if iso_val := self.iso:
            if iso_val.startswith(('https://', 'http://')):
                if not (iso := Path(BASE_FOLDER, 'iso', iso_val.rsplit('/', 1)[1])).exists():
                    iso.parent.mkdir(exist_ok=True, parents=True)
                    lib.utils.run(['wget', '-c', '-O', iso, iso_val], show_cmd=True)
            else:
                iso = Path(iso_val)
            if not iso.exists():
                raise RuntimeError(
                    f"{iso.name} does not exist at {iso}, was the wrong path used or did the download fail?",
                )
            args += [
                '-device', 'virtio-scsi-pci,id=scsi0',
                '-device', 'scsi-cd,drive=cd',
                '-drive', f"if=none,format=raw,id=cd,file={iso}",
            ]  # yapf: disable

        for image in self._images_to_mount:
            args += ['-drive', f"if=virtio,format={self._get_image_format(image)},file={image}"]

        if self._use_kvm:
            args += ['-cpu', self._kvm_cpu, '-enable-kvm']

        return args

    def _get_image_format(self, image):
        qemu_img_cmd = ['qemu-img', 'info', '--output', 'json', image]
        json_output = json.loads(lib.utils.chronic(qemu_img_cmd).stdout)

        if (img_format := json_output['format']) in ('qcow2', 'raw'):
            return img_format
        raise ValueError(f"Unhandled image format: {img_format}")

    # Public interfaces
    def remove(self):
        if self._data_folder.is_dir():
            shutil.rmtree(self._data_folder)

    def run(self):
        if not self._primary_disk_img.exists():
            raise RuntimeError(
                f"Disk image ('{self._primary_disk_img}') for virtual machine ('{self.name}') does not exist, run 'setup' first?",
            )

        # pylint: disable-next=superfluous-parens
        if not (qemu := shutil.which(self._qemu)):
            raise RuntimeError(
                f"Could not find QEMU binary ('{self._qemu}') on your system (needed to run virtual machine)!",
            )

        if not ((sudo := shutil.which('doas')) or (sudo := shutil.which('sudo'))):
            raise RuntimeError(
                'Could not find doas or sudo on your system (needed for virtiofsd integration)!')

        possible_vfsd_locations = [
            Path('/usr/lib/virtiofsd'),  # Arch Linux
            Path('/usr/libexec/virtiofsd'),  # Fedora
        ]
        virtiofsd = find_first_file(possible_vfsd_locations)

        # Get access to root privileges permission before opening virtiofsd in
        # the background
        lib.utils.request_root('run virtiofsd')

        # Transiently create virtiofsd socket, as root might not have
        # permission to write to $VM_FOLDER. We manually manage this instead of
        # using a context manager because we have a finally clause below that
        # allows us to guarantee it is always cleaned up and it allows us to
        # avoid a level of indentation, which is precious at this point.
        # pylint: disable-next=consider-using-with
        tmpdir = TemporaryDirectory()
        vfsd_sock = f"{tmpdir.name}/vfsd.sock"
        self.qemu_args += ['-chardev', f"socket,id=char0,path={vfsd_sock}"]

        # Only the Rust virtiofsd implementation is supported now
        virtiofsd_cmd = [
            sudo, virtiofsd,
            '--cache', 'always',
            '--shared-dir', self._shared_folder,
            '--socket-group', grp.getgrgid(os.getgid()).gr_name,
            '--socket-path', vfsd_sock,
        ]  # yapf: disable
        if lib.utils.in_nspawn():
            # In systemd-nspawn, our host UID is different from the guest
            # UID, so we need to translate it to avoid permission errors.
            host_uid = 1000  # this should be generally true
            nspawn_uid = os.getuid()
            nspawn_gid = os.getgid()
            virtiofsd_cmd += [
                '--translate-gid', f"squash-guest:0:{nspawn_gid}:4294967295",
                '--translate-gid', f"host:{nspawn_gid}:{host_uid}:1",
                '--translate-uid', f"squash-guest:0:{nspawn_uid}:4294967295",
                '--translate-uid', f"host:{nspawn_uid}:{host_uid}:1",
            ]  # yapf: disable

        # Ensure shared folder is created before sharing
        self._shared_folder.mkdir(exist_ok=True, parents=True)

        # Clear any previous hosts using the chosen SSH port.
        if Path.home().joinpath('.ssh/known_hosts').exists():
            lib.utils.run(['ssh-keygen', '-R', f"[localhost]:{self.ssh_port}"], show_cmd=True)
            Path.home().joinpath('.ssh/known_hosts.old').unlink(missing_ok=True)

        # Python recommends full paths with subprocess.Popen() calls
        lib.utils.print_cmd(virtiofsd_cmd)
        with Path(self._data_folder, 'vfsd.log').open('w+', encoding='utf-8') as file, \
             subprocess.Popen(virtiofsd_cmd, stderr=file, stdout=file) as vfsd:
            # Give virtiofsd a second to start up before calling connect() with
            # QEMU, otherwise we may get weird 'Permission denied' errors
            time.sleep(1)
            try:
                qemu_cmd = [qemu, *self.qemu_args, *self._gen_dynamic_qemu_args()]
                lib.utils.run(qemu_cmd, show_cmd=True)
            except subprocess.CalledProcessError as err:
                # If virtiofsd is dead, it is pretty likely that it was the
                # cause of QEMU failing so add to the existing exception using
                # 'from'.
                if vfsd.poll():
                    file.seek(0)
                    raise RuntimeError(
                        f"virtiofsd failed with: {file.read(encoding='utf-8')}") from err
                raise err
            finally:
                vfsd.kill()
                tmpdir.cleanup()

    def setup(self):
        self.remove()
        self._create_disk_img()
        self.run()


class ArmVirtualMachine(VirtualMachine):

    def __init__(self, arch, name):
        super().__init__(arch, name)

        self.qemu_args += ['-M', 'virt']

    def _setup_efi_files(self, possible_efi_files=None):
        if not possible_efi_files:
            raise RuntimeError('No EFI files provided?')

        efi_img_size = 64 * 1024 * 1024  # 64M

        self._efi_img.parent.mkdir(exist_ok=True, parents=True)

        if not self._efi_img.exists():
            shutil.copyfile(find_first_file(possible_efi_files), self._efi_img)
            with self._efi_img.open(mode='r+b') as file:
                file.truncate(efi_img_size)

        if not self._efi_vars_img.exists():
            with self._efi_vars_img.open(mode='xb') as file:
                file.truncate(efi_img_size)

    def run(self):
        self._setup_efi_files()
        super().run()


class Arm32VirtualMachine(ArmVirtualMachine):

    def __init__(self, name):
        super().__init__('arm', name)

        if HOST_ARCH == 'aarch64':
            if not (check_el1_32 := Path(BASE_FOLDER,
                                         'utils/aarch64_32_bit_el1_supported')).exists():
                check_el1_32.parent.mkdir(exist_ok=False, parents=True)
                lib.utils.curl(
                    f"https://github.com/ClangBuiltLinux/boot-utils/raw/main/utils/{check_el1_32.name}",
                    check_el1_32)
                check_el1_32.chmod(0o755)

            self._use_kvm = DEV_KVM_ACCESS and lib.utils.run_check_rc_zero(check_el1_32)
            if self._use_kvm:
                self._kvm_cpu += ',aarch64=off'
                self._qemu = 'qemu-system-aarch64'

    def _setup_efi_files(self, possible_efi_files=None):
        possible_efi_files = [
            Path('/usr/share/edk2/arm/QEMU_EFI.fd'),  # Arch Linux, Fedora
        ]
        super()._setup_efi_files(possible_efi_files)


class Arm64VirtualMachine(ArmVirtualMachine):

    def __init__(self, name):
        super().__init__('aarch64', name)

        # If not running on KVM, use QEMU's max CPU emulation target
        # Use impdef pointer auth, otherwise QEMU is just BRUTALLY slow:
        # https://lore.kernel.org/YlgVa+AP0g4IYvzN@lakrids/
        if not self._use_kvm:
            self.qemu_args += ['-cpu', 'max,pauth-impdef=true']

    def _setup_efi_files(self, possible_efi_files=None):
        possible_efi_files = [
            Path('/usr/share/edk2/aarch64/QEMU_EFI.silent.fd'),  # Fedora
            Path('/usr/share/edk2/aarch64/QEMU_EFI.fd'),  # Arch Linux
            Path("/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"),  # Debian and Ubuntu
        ]
        super()._setup_efi_files(possible_efi_files)


class X86VirtualMachine(VirtualMachine):

    def __init__(self, arch, name):
        super().__init__(arch, name)

        self.qemu_args += ['-M', 'q35']

    def _setup_efi_files(self, possible_efi_files=None, possible_efi_vars_files=None):
        if not possible_efi_files:
            raise RuntimeError('No EFI files provided?')
        if not possible_efi_vars_files:
            raise RuntimeError('No EFI variable files provided?')

        self._efi_img.parent.mkdir(exist_ok=True, parents=True)

        if not self._efi_img.exists():
            shutil.copyfile(find_first_file(possible_efi_files), self._efi_img)

        if not self._efi_vars_img.exists():
            shutil.copyfile(find_first_file(possible_efi_vars_files), self._efi_vars_img)

    def run(self):
        self._setup_efi_files()
        super().run()


class X8632VirtualMachine(X86VirtualMachine):

    def __init__(self, name):
        super().__init__('i386', name)

        self._use_kvm = DEV_KVM_ACCESS and HOST_ARCH == 'x86_64'

    def _setup_efi_files(self, possible_efi_files=None, possible_efi_vars_files=None):
        possible_efi_files = [
            Path('/usr/share/edk2/ia32/OVMF_CODE.4m.fd'),  # Arch Linux (4MB location)
            Path('/usr/share/edk2/ia32/OVMF_CODE.fd'),  # Arch Linux (2MB location)
            Path('/usr/share/edk2/ovmf-ia32/OVMF_CODE.fd'),  # Fedora
            Path('/usr/share/OVMF/OVMF32_CODE_4M.secboot.fd'),  # Debian and Ubuntu
        ]
        possible_efi_vars_files = [
            Path('/usr/share/edk2/ia32/OVMF_VARS.4m.fd'),  # Arch Linux (4MB location)
            Path('/usr/share/edk2/ia32/OVMF_VARS.fd'),  # Arch Linux (2MB location)
            Path('/usr/share/edk2/ovmf-ia32/OVMF_VARS.fd'),  # Fedora
            Path('/usr/share/OVMF/OVMF32_VARS_4M.fd'),  # Debian and Ubuntu
        ]
        super()._setup_efi_files(possible_efi_files, possible_efi_vars_files)


class X8664VirtualMachine(X86VirtualMachine):

    def __init__(self, name):
        super().__init__('x86_64', name)

    def _setup_efi_files(self, possible_efi_files=None, possible_efi_vars_files=None):
        possible_efi_files = [
            Path('/usr/share/edk2/x64/OVMF_CODE.4m.fd'),  # Arch Linux (4MB location)
            Path('/usr/share/edk2/x64/OVMF_CODE.fd'),  # Arch Linux (2MB location) and Fedora
            Path("/usr/share/OVMF/OVMF_CODE.fd"),  # Debian and Ubuntu
        ]
        possible_efi_vars_files = [
            Path('/usr/share/edk2/x64/OVMF_VARS.4m.fd'),  # Arch Linux (4MB location)
            Path('/usr/share/edk2/x64/OVMF_VARS.fd'),  # Arch Linux (2MB location) and Fedora
            Path('/usr/share/OVMF/OVMF_VARS.fd'),  # Debian and Ubuntu
        ]
        super()._setup_efi_files(possible_efi_files, possible_efi_vars_files)


def parse_arguments():
    parser = ArgumentParser()
    subparsers = parser.add_subparsers(help='Action to perform', required=True)

    # Common arguments for all subcommands
    common_parser = ArgumentParser(add_help=False)
    common_parser.add_argument('-a',
                               '--architecture',
                               type=str,
                               default=HOST_ARCH,
                               help='Architecture of virtual machine (default: %(default)s)')
    common_parser.add_argument(
        '-c',
        '--cores',
        type=int,
        help='Number of cores virtual machine has (default: based on profile)')
    if 'DISPLAY' in os.environ:
        common_parser.add_argument('-G',
                                   '--graphical',
                                   action='store_true',
                                   help='Run QEMU graphically (default: False)')
    common_parser.add_argument(
        '-m',
        '--memory',
        type=int,
        help=
        'Amount of memory in gigabytes to allocate to virtual machine (default: based on profile)')
    common_parser.add_argument(
        '-n',
        '--name',
        type=str,
        help=
        'Name of virtual machine (default: chosen based on default distribution for architecture)')
    common_parser.add_argument('-p',
                               '--ssh-port',
                               type=int,
                               help='Port to forward ssh on (default: 8022)')
    common_parser.add_argument(
        '-P',
        '--profile',
        choices=['regular', 'build'],
        help='Choose a specific profile, which customizes the default ratio of cores and memory')

    # Arguments for "list"
    list_parser = subparsers.add_parser('list',
                                        help='List virtual machines that can be run',
                                        parents=[common_parser])
    list_parser.set_defaults(action='list')

    # Arguments for "setup"
    setup_parser = subparsers.add_parser('setup',
                                         help='Run virtual machine for first time',
                                         parents=[common_parser])
    setup_parser.add_argument('-i',
                              '--iso',
                              required=True,
                              type=str,
                              help='Path or URL of .iso to boot from')
    setup_parser.add_argument(
        '-s',
        '--size',
        type=int,
        help='Size of virtual machine disk image in gigabytes (default: 75GB)')
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
    run_parser.add_argument('-i', '--initrd', type=Path, help='Path to initrd')
    run_parser.add_argument('-I', '--iso', type=str, help='Path or URL of .iso to boot from')
    run_parser.add_argument('-k',
                            '--kernel',
                            type=Path,
                            help='Path to kernel image or kernel build directory')
    run_parser.set_defaults(action='run')

    return parser.parse_args()


def main():
    # Get arguments
    args = parse_arguments()
    arch = args.architecture

    if args.action == 'list':
        print(f"\nAvailable virtual machines for {arch}:\n")

        if (arch_folder := Path(BASE_FOLDER, arch)).exists() and (vms := sorted(
                elem.name for elem in arch_folder.iterdir() if elem.is_dir())):
            print('\n'.join(vms))
        else:
            print('None')
        sys.exit(0)

    if not (name := args.name):
        name = DEFAULT_DISTRO[arch]

    vm = {
        'aarch64': Arm64VirtualMachine,
        'arm64': Arm64VirtualMachine,
        'arm': Arm32VirtualMachine,
        'armv7l': Arm32VirtualMachine,
        'i386': X8632VirtualMachine,
        'i686': X8632VirtualMachine,
        'x86_64': X8664VirtualMachine,
    }[arch](name)

    # Parse common arguments
    if args.cores:
        vm.cores = args.cores
    if args.memory:
        vm.memory = args.memory
    if args.profile:
        vm.profile = args.profile
    if args.ssh_port:
        vm.ssh_port = args.ssh_port

    # Handle optional arguments
    if getattr(args, 'gdb', False):
        vm.qemu_args += ['-s', '-S']
    if getattr(args, 'graphical', False):
        vm.qemu_args += ['-device', 'virtio-vga-gl', '-display', 'gtk,gl=on']
    if iso := getattr(args, 'iso', None):
        vm.iso = iso
    if size := getattr(args, 'size', 0):
        vm.size = size

    # cmdline and initrd are only handled when kernel is passed
    if k_arg := getattr(args, 'kernel', None):
        if (kernel := k_arg).is_dir():
            kernel = Path(k_arg, DEFAULT_KERNEL_PATH[vm.arch])
        if not kernel.exists():
            raise RuntimeError(
                f"Kernel image ('{kernel}'), derived from kernel argument ('{k_arg}'), does not exist!",
            )
        vm.kernel = kernel
        if args.cmdline:
            vm.cmdline = args.cmdline
        if args.initrd:
            vm.initrd = args.initrd

    if args.action == 'setup':
        return vm.setup()
    if args.action == 'remove':
        return vm.remove()
    if args.action == 'run':
        return vm.run()
    raise RuntimeError(f"Unimplemented action ('{args.action}')?")


if __name__ == '__main__':
    main()
