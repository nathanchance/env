#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor
# Description: Virtual machine manager for ClangBuiltLinux development
# Cobbled together from:
# https://wiki.archlinux.org/title/QEMU
# https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface#Testing_UEFI_in_systems_without_native_support
# https://mirrors.edge.kernel.org/pub/linux/kernel/people/will/docs/qemu/qemu-arm64-howto.html
# https://wiki.qemu.org/Documentation/Networking

from argparse import ArgumentParser
import datetime
import grp
import math
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys

sys.path.append(str(Path(__file__).resolve().parents[1]))
# pylint: disable=wrong-import-position
import lib.utils  # noqa: E402
# pylint: enable=wrong-import-position

usr_share = Path('/usr/share')


def find_first_file(possible_files, relative_root=usr_share):
    for possible_file in possible_files:
        if (full_path := Path(relative_root, possible_file)).exists():
            return full_path
    files_str = "', '".join([str(elem) for elem in possible_files])
    raise RuntimeError(
        f"No items from list ('{files_str}') could be found in '{relative_root}', do you need to install a package?",
    )


def get_base_folder():
    if 'VM_FOLDER' in os.environ:
        return Path(os.environ['VM_FOLDER'])
    return Path(__file__).resolve().parent.joinpath('vm')


def have_dev_kvm_access():
    return os.access('/dev/kvm', os.R_OK | os.W_OK)


def iso_is_url(iso):
    return 'http://' in iso or 'https://' in iso


def run_cmd(cmd):
    lib.utils.print_cmd(cmd)
    subprocess.run(cmd, check=True)


def wget(location, url):
    run_cmd(['wget', '-c', '-O', location, url])


class VirtualMachine:

    def __init__(self, arch, cmdline, cores, gdb, graphical, initrd, iso, kernel, kvm_cpu, memory,
                 name, size, ssh_port):
        # External values
        self.arch = arch
        self.name = name
        self.size = size

        # Internal values
        self.data_folder = Path(get_base_folder(), self.arch, self.name)
        self.efi_img = Path(self.data_folder, 'efi.img')
        self.efi_vars_img = Path(self.data_folder, 'efi_vars.img')
        self.images_to_mount = (x for x in Path(self.data_folder).glob('*.img')
                                if 'efi' not in x.name)
        self.primary_disk_img = Path(self.data_folder, 'disk.img')
        self.shared_folder = Path(self.data_folder, 'shared')
        self.use_kvm = self.can_use_kvm()
        self.vfsd_log = Path(self.data_folder, 'vfsd.log')
        self.vfsd_sock = Path(self.data_folder, 'vfsd.sock')
        self.vfsd_mem = Path(self.data_folder, 'vfsd.mem')

        # When using KVM, we cannot use more than the maximum number of cores.
        # Default to either 8 cores or half the number of cores in the machine,
        # whichever is smaller. For TCG, use 4 cores by default.
        if not cores:
            cores = min(8, int(os.cpu_count() / 2)) if self.use_kvm else 4
        # We cap the default amount of memory at two times the number of cores
        # (as that is sufficient for compiling) or total amount of available VM
        # memory.
        if not memory:
            memory = min(cores * 2, self.get_available_mem_for_vm())

        # Attempt to locate static kernel files if only a kernel was passed
        if kernel:
            kernel_files = Path(self.shared_folder, 'kernel_files')
            if not cmdline:
                if not (cmdline_file := Path(kernel_files, 'cmdline')).exists():
                    raise RuntimeError('kernel passed without cmdline and one could not be found!')
                cmdline = cmdline_file.read_text(encoding='utf-8')
            if not (initrd or (initrd := Path(kernel_files, 'initramfs')).exists()):
                raise RuntimeError('kernel passed without initrd and one could not be found!')

        # Clear any previous hosts using the chosen SSH port.
        run_cmd(['ssh-keygen', '-R', f"[localhost]:{ssh_port}"])
        Path.home().joinpath('.ssh/known_hosts.old').unlink(missing_ok=True)

        # QEMU configuration
        self.qemu = 'qemu-system-' + self.arch
        self.qemu_args = [
            # Display
            *self.get_display_args(graphical),

            # Networking
            '-nic', f"user,model=virtio-net-pci,hostfwd=tcp::{ssh_port}-:22",

            # RNG
            '-object', 'rng-random,filename=/dev/urandom,id=rng0',
            '-device', 'virtio-rng-pci',

            # Shared folder via virtiofs
            '-chardev', f"socket,id=char0,path={self.vfsd_sock}",
            '-device', 'vhost-user-fs-pci,queue-size=1024,chardev=char0,tag=host',
            '-object', f"memory-backend-file,id=shm,mem-path={self.vfsd_mem},share=on,size={memory}G",
            '-numa', 'node,memdev=shm',

            # Statistics
            '-m', f"{memory}G",
            '-device', 'virtio-balloon',
            '-smp', str(cores),

            # UEFI
            '-drive', f"if=pflash,format=raw,file={self.efi_img},readonly=on",
            '-drive', f"if=pflash,format=raw,file={self.efi_vars_img}",

            # iso args if setting up machine for the first time
            *self.get_iso_args(iso),
        ]  # yapf: disable
        if self.use_kvm:
            self.qemu_args += ['-cpu', kvm_cpu, '-enable-kvm']
        if cmdline:
            self.qemu_args += ['-append', cmdline.strip()]
        if gdb:
            self.qemu_args += ['-s', '-S']
        if initrd:
            self.qemu_args += ['-initrd', initrd]
        if kernel:
            self.qemu_args += ['-kernel', kernel]

    def can_use_kvm(self):
        if self.arch == platform.machine():
            return have_dev_kvm_access()
        return False

    # We consider half of the host's memory in gigabytes as available for normal
    # virtual machines. Certain ones might have other requirements.
    def get_available_mem_for_vm(self):
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

    def handle_action(self, action):
        if action == 'setup':
            return self.setup()
        if action == 'remove':
            return self.remove()
        if action == 'run':
            return self.run()
        raise RuntimeError(f"Unimplemented action ('{action}')?")

    def create_disk_img(self):
        self.primary_disk_img.parent.mkdir(exist_ok=True, parents=True)
        run_cmd(['qemu-img', 'create', '-f', 'qcow2', self.primary_disk_img, self.size])

    def get_display_args(self, graphical):
        if graphical:
            return [
                '-device', 'virtio-vga-gl',
                '-display', 'gtk,gl=on',
            ]  # yapf: disable
        return [
            '-display', 'none',
            '-serial', 'mon:stdio',
        ]  # yapf: disable

    def get_drive_args(self):
        drive_args = []
        for image in self.images_to_mount:
            drive_args += ['-drive', f"if=virtio,format=qcow2,file={image}"]
        return drive_args

    def get_iso_args(self, iso):
        if iso is None:
            return []

        # Download iso if necessary
        if iso_is_url(str(iso)):
            iso_url = iso
            if not (iso := Path(get_base_folder(), 'iso', iso_url.split('/')[-1])).exists():
                iso.parent.mkdir(exist_ok=True, parents=True)
                wget(iso, iso_url)

        if not iso.exists():
            raise RuntimeError(
                f"{iso.name} does not exist at {iso}, was the wrong path used or did the download fail?",
            )

        return [
            '-device', 'virtio-scsi-pci,id=scsi0',
            '-device', 'scsi-cd,drive=cd',
            '-drive', f"if=none,format=raw,id=cd,file={iso}",
        ]  # yapf: disable

    def remove(self):
        if self.data_folder.is_dir():
            shutil.rmtree(self.data_folder)

    def run(self):
        if not self.primary_disk_img.exists():
            raise RuntimeError(
                f"Disk image ('{self.primary_disk_img}') for virtual machine ('{self.name}') does not exist, run 'setup' first?",
            )

        if not (qemu := shutil.which(self.qemu)):
            raise RuntimeError(
                f"Could not find QEMU binary ('{self.qemu}') on your system (needed to run virtual machine)!",
            )

        if not ((sudo := shutil.which('doas')) or (sudo := shutil.which('sudo'))):
            raise RuntimeError(
                'Could not find doas or sudo on your system (needed for virtiofsd integration)!')

        # Locate the QEMU prefix to search for virtiofsd
        if not (virtiofsd := shutil.which('virtiofsd')):
            qemu = Path(qemu).resolve()
            if not (virtiofsd := Path(qemu.parent, 'tools/virtiofsd/virtiofsd')).exists():
                possible_files = [
                    Path('/usr/lib/virtiofsd'),  # Arch Linux (virtiofsd)
                    Path('libexec/virtiofsd'),  # Default QEMU installation, Fedora
                    Path('lib/qemu/virtiofsd'),  # Arch Linux (qemu-virtiofsd)
                ]
                virtiofsd = find_first_file(possible_files, relative_root=qemu.parents[1])

        # Ensure shared folder is created before sharing
        self.shared_folder.mkdir(exist_ok=True, parents=True)

        # Get access to root privileges permission before opening virtiofsd in
        # the background
        print('Requesting root privileges to run virtiofsd...')
        run_cmd([sudo, 'true'])

        base_virtiofsd_cmd = [sudo, virtiofsd]
        virtiofsd_version_text = subprocess.run([*base_virtiofsd_cmd, '--version'],
                                                capture_output=True,
                                                check=True,
                                                text=True).stdout
        group_name = grp.getgrgid(os.getgid()).gr_name

        # C / QEMU / Reference implementation (deprecated)
        if 'virtiofsd version' in virtiofsd_version_text:
            virtiofsd_args = [
                f"--socket-group={group_name}",
                f"--socket-path={self.vfsd_sock}",
                '-o', 'cache=always',
                '-o', f"source={self.shared_folder}",
            ]  # yapf: disable
        # Rust implementation
        else:
            virtiofsd_args = [
                '--cache', 'always',
                '--shared-dir', self.shared_folder,
                '--socket-group', group_name,
                '--socket-path', self.vfsd_sock,
            ]  # yapf: disable

        # Python recommends full paths with subprocess.Popen() calls
        virtiofsd_cmd = [*base_virtiofsd_cmd, *virtiofsd_args]
        lib.utils.print_cmd(virtiofsd_cmd)
        with self.vfsd_log.open('w', encoding='utf-8') as file, \
             subprocess.Popen(virtiofsd_cmd, stderr=file, stdout=file) as vfsd:
            try:
                run_cmd([qemu, *self.qemu_args, *self.get_drive_args()])
            except subprocess.CalledProcessError as err:
                # If virtiofsd is dead, it is pretty likely that it was the
                # cause of QEMU failing so add to the existing exception using
                # 'from'.
                if vfsd.poll():
                    vfsd_log_txt = self.vfsd_log.read_text(encoding='utf-8')
                    raise RuntimeError(f"virtiofsd failed with: {vfsd_log_txt}") from err
                raise err
            finally:
                vfsd.kill()
                # Delete the memory to save space, it does not have to be persistent
                self.vfsd_mem.unlink(missing_ok=True)

    def setup(self):
        self.remove()
        self.create_disk_img()
        self.run()


class ArmVirtualMachine(VirtualMachine):

    def __init__(self, arch, cmdline, cores, gdb, graphical, initrd, iso, kernel, kvm_cpu, memory,
                 name, size, ssh_port):
        super().__init__(arch, cmdline, cores, gdb, graphical, initrd, iso, kernel, kvm_cpu, memory,
                         name, size, ssh_port)

        self.qemu_args += ['-M', 'virt']

    def run(self):
        self.setup_efi_files()
        super().run()

    def setup_efi_files(self, possible_efi_files=None):
        if not possible_efi_files:
            raise RuntimeError('No EFI files provided?')

        efi_img_size = 64 * 1024 * 1024  # 64M

        self.efi_img.parent.mkdir(exist_ok=True, parents=True)

        if not self.efi_img.exists():
            shutil.copyfile(find_first_file(possible_efi_files), self.efi_img)
            with self.efi_img.open(mode='r+b') as file:
                file.truncate(efi_img_size)

        if not self.efi_vars_img.exists():
            with self.efi_vars_img.open(mode='xb') as file:
                file.truncate(efi_img_size)


class Arm32VirtualMachine(ArmVirtualMachine):

    def __init__(self, cmdline, cores, gdb, graphical, initrd, iso, kernel, memory, name, size,
                 ssh_port):
        super().__init__('arm', cmdline, cores, gdb, graphical, initrd, iso, kernel,
                         'host,aarch64=off', memory, name, size, ssh_port)

        if self.use_kvm:
            self.qemu = 'qemu-system-aarch64'

    def can_use_kvm(self):
        if platform.machine() == 'aarch64':
            check_el1_32 = Path(get_base_folder(), 'utils/aarch64_32_bit_el1_supported')
            if not check_el1_32.exists():
                check_el1_32.parent.mkdir(exist_ok=False, parents=True)
                wget(
                    check_el1_32,
                    f"https://github.com/ClangBuiltLinux/boot-utils/raw/main/utils/{check_el1_32.name}",
                )
                check_el1_32.chmod(0o755)
            try:
                subprocess.run(check_el1_32, check=True)
            except subprocess.CalledProcessError:
                pass  # we'll return false below
            else:
                return have_dev_kvm_access()
        return False

    def setup_efi_files(self, possible_efi_files=None):
        possible_efi_files = [
            Path('edk2/arm/QEMU_EFI.fd'),  # Arch Linux, Fedora
        ]
        super().setup_efi_files(possible_efi_files)


class Arm64VirtualMachine(ArmVirtualMachine):

    def __init__(self, cmdline, cores, gdb, graphical, initrd, iso, kernel, memory, name, size,
                 ssh_port):
        super().__init__('aarch64', cmdline, cores, gdb, graphical, initrd, iso, kernel, 'host',
                         memory, name, size, ssh_port)

        # If not running on KVM, use QEMU's max CPU emulation target
        # Use impdef pointer auth, otherwise QEMU is just BRUTALLY slow:
        # https://lore.kernel.org/YlgVa+AP0g4IYvzN@lakrids/
        if '-cpu' not in self.qemu_args:
            self.qemu_args += ['-cpu', 'max,pauth-impdef=true']

    def setup_efi_files(self, possible_efi_files=None):
        possible_efi_files = [
            Path('edk2/aarch64/QEMU_EFI.silent.fd'),  # Fedora
            Path('edk2/aarch64/QEMU_EFI.fd'),  # Arch Linux (current)
            Path('edk2-armvirt/aarch64/QEMU_EFI.fd'),  # Arch Linux (old),
            Path("qemu-efi-aarch64/QEMU_EFI.fd"),  # Debian and Ubuntu
        ]
        super().setup_efi_files(possible_efi_files)


class X86VirtualMachine(VirtualMachine):

    def __init__(self, arch, cmdline, cores, gdb, graphical, initrd, iso, kernel, memory, name,
                 size, ssh_port):
        super().__init__(arch, cmdline, cores, gdb, graphical, initrd, iso, kernel, 'host', memory,
                         name, size, ssh_port)

        self.qemu_args += ['-M', 'q35']

    def run(self):
        self.setup_efi_files()
        super().run()

    def setup_efi_files(self, possible_efi_files=None, possible_efi_vars_files=None):
        if not possible_efi_files:
            raise RuntimeError('No EFI files provided?')
        if not possible_efi_vars_files:
            raise RuntimeError('No EFI variable files provided?')

        self.efi_img.parent.mkdir(exist_ok=True, parents=True)

        if not self.efi_img.exists():
            shutil.copyfile(find_first_file(possible_efi_files), self.efi_img)

        if not self.efi_vars_img.exists():
            shutil.copyfile(find_first_file(possible_efi_vars_files), self.efi_vars_img)


class X8632VirtualMachine(X86VirtualMachine):

    def __init__(self, cmdline, cores, gdb, graphical, initrd, iso, kernel, memory, name, size,
                 ssh_port):
        super().__init__('i386', cmdline, cores, gdb, graphical, initrd, iso, kernel, memory, name,
                         size, ssh_port)

    def can_use_kvm(self):
        if platform.machine() in ('i386', 'i686', 'x86_64'):
            return have_dev_kvm_access()
        return False

    def setup_efi_files(self, possible_efi_files=None, possible_efi_vars_files=None):
        possible_efi_files = [
            Path('edk2/ia32/OVMF_CODE.fd'),  # Arch Linux
            Path('edk2/ovmf-ia32/OVMF_CODE.fd'),  # Fedora
            Path("OVMF/OVMF32_CODE_4M.secboot.fd"),  # Debian and Ubuntu
        ]
        possible_efi_vars_files = [
            Path('edk2/ia32/OVMF_VARS.fd'),  # Arch Linux
            Path('edk2/ovmf-ia32/OVMF_VARS.fd'),  # Fedora
            Path("OVMF/OVMF32_VARS_4M.fd"),  # Debian and Ubuntu
        ]
        super().setup_efi_files(possible_efi_files, possible_efi_vars_files)


class X8664VirtualMachine(X86VirtualMachine):

    def __init__(self, cmdline, cores, gdb, graphical, initrd, iso, kernel, memory, name, size,
                 ssh_port):
        super().__init__('x86_64', cmdline, cores, gdb, graphical, initrd, iso, kernel, memory,
                         name, size, ssh_port)

    def setup_efi_files(self, possible_efi_files=None, possible_efi_vars_files=None):
        possible_efi_files = [
            Path('edk2/x64/OVMF_CODE.fd'),  # Arch Linux and Fedora
            Path("OVMF/OVMF_CODE.fd"),  # Debian and Ubuntu
        ]
        possible_efi_vars_files = [
            Path("edk2/x64/OVMF_VARS.fd"),  # Arch Linux and Fedora
            Path("OVMF/OVMF_VARS.fd"),  # Debian and Ubuntu
        ]
        super().setup_efi_files(possible_efi_files, possible_efi_vars_files)


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
    if 'DISPLAY' in os.environ:
        common_parser.add_argument('-G',
                                   '--graphical',
                                   action='store_true',
                                   help='Run QEMU graphically')
    common_parser.add_argument('-m',
                               '--memory',
                               type=int,
                               help='Amount of memory in gigabytes to allocate to virtual machine')
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


def get_def_iso(arch):
    alpine_ver = '3.17.3'

    arch_day = '.01'
    arch_iso_ver = datetime.datetime.now(datetime.timezone.utc).strftime("%Y.%m") + arch_day

    debian_ver = '12.0.0'

    fedora_ver = '38'
    fedora_iso_ver = '1.6'

    iso_info = {
        'arm': {
            'file': Path('Debian', debian_ver, 'armhf', f"debian-{debian_ver}-armhf-netinst.iso"),
            'url': f"https://cdimage.debian.org/debian-cd/current/armhf/iso-cd/debian-{debian_ver}-armhf-netinst.iso",
        },
        'aarch64': {
            'file': Path('Fedora', fedora_ver, 'Server', f"Fedora-Server-netinst-{arch}-{fedora_ver}-{fedora_iso_ver}.iso"),
            'url': f"https://download.fedoraproject.org/pub/fedora/linux/releases/{fedora_ver}/Server/{arch}",
        },
        'i386': {
            'file': Path('Alpine', alpine_ver, f"alpine-virt-{alpine_ver}-x86.iso"),
            'url': f"https://dl-cdn.alpinelinux.org/alpine/v{'.'.join(alpine_ver.split('.')[0:2])}/releases/x86",
        },
        'x86_64': {
            'file': Path('Arch', arch_iso_ver, f"archlinux-{arch_iso_ver}-x86_64.iso"),
            'url': 'https://mirrors.edge.kernel.org/archlinux/iso/',
        },
    }  # yapf: disable
    iso_info['i686'] = iso_info['i386']

    # Check to see if we have a local network version we can use
    file = iso_info[arch]['file']
    if 'NAS_FOLDER' in os.environ and (iso := Path(os.environ['NAS_FOLDER'], 'Firmware_and_Images',
                                                   file)).exists():
        return iso

    # Otherwise, return the URL so that it can be fetched and cached on the
    # machine
    return f"{iso_info[arch]['url']}/{file.name}"


def create_vm_from_args(args):
    # Simple configuration section with short one liners with no logic. Either
    # it came from argparse (meaning the default was able to be set there or
    # the user customized it) or we use a default from the dictionary below.
    # Some options are dynamically calculated using the functions above.
    # hasattr() is used to check if the option exists within argparse, as
    # certain flags are only available for certain modes.
    arch = args.architecture
    static_defaults = {
        'arm': {
            'kernel': Path('arch/arm/boot/zImage'),
            'name': 'debian',
        },
        'aarch64': {
            'kernel': Path('arch/arm64/boot/Image'),
            'name': 'fedora',
        },
        'i386': {
            'kernel': Path('arch/x86/boot/bzImage'),
            'name': 'alpine',
        },
        'x86_64': {
            'kernel': Path('arch/x86/boot/bzImage'),
            'name': 'arch',
        },
        'iso': get_def_iso(arch),
    }
    # platform.machine() to QEMU mapping
    static_defaults['i686'] = static_defaults['i386']
    # Part of common parser, so present for all arguments
    cores = args.cores
    memory = args.memory
    name = args.name if args.name else static_defaults[arch]['name']
    ssh_port = args.ssh_port
    # Not necessary for all invocations
    graphical = args.graphical if hasattr(args, 'graphical') else False
    gdb = args.gdb if hasattr(args, 'gdb') else False
    size = args.size if hasattr(args, 'size') else None

    # Default .iso
    # Check if iso is even in the current args, as it is only required for
    # 'setup'. If the user supplied one, check if it is a url; if not, it has
    # to be a path. If the user did not supply an iso, get the default one.
    iso = None
    if hasattr(args, 'iso'):
        if args.iso:
            iso = args.iso if iso_is_url(args.iso) else Path(args.iso)
        else:
            iso = get_def_iso(arch)

    # Support for running custom kernel image (only available when actually
    # running a machine). More windy logic due to implicit defaults.
    cmdline = None
    initrd = None
    kernel = None
    if hasattr(args, 'kernel') and args.kernel:
        # Figure out whether kernel argument is build folder or kernel image
        if (kernel := Path(args.kernel)).is_dir():
            kernel_folder = kernel
            kernel = Path(kernel_folder, static_defaults[arch]['kernel'])
        else:
            kernel_folder = None
        if not kernel.exists():
            raise RuntimeError(
                f"Kernel image ('{kernel}'), derived from kernel argument ('{args.kernel}'), does not exist!",
            )

        # Handle command line and initial ramdisk
        if args.cmdline:
            cmdline = args.cmdline
        if args.initrd:
            initrd = Path(args.initrd)

    # Create the VirtualMachine object for the particular architecture.
    if arch == 'arm':
        return Arm32VirtualMachine(cmdline, cores, gdb, graphical, initrd, iso, kernel, memory,
                                   name, size, ssh_port)
    if arch == 'aarch64':
        return Arm64VirtualMachine(cmdline, cores, gdb, graphical, initrd, iso, kernel, memory,
                                   name, size, ssh_port)
    if arch in ('i386', 'i686'):
        return X8632VirtualMachine(cmdline, cores, gdb, graphical, initrd, iso, kernel, memory,
                                   name, size, ssh_port)
    if arch == 'x86_64':
        return X8664VirtualMachine(cmdline, cores, gdb, graphical, initrd, iso, kernel, memory,
                                   name, size, ssh_port)
    raise RuntimeError(f"Unimplemented architecture ('{arch}')?")


def list_vms(arch):
    print(f"\nAvailable virtual machines for {arch}:\n")

    if (arch_folder := Path(get_base_folder(), arch)).exists():
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
