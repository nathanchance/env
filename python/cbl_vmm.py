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
from math import log2
from os import cpu_count, environ, listdir, sysconf
from pathlib import Path
from platform import machine
from shlex import quote
from shutil import copyfile, rmtree
from subprocess import run


def parse_parameters():
    parser = ArgumentParser()
    subparsers = parser.add_subparsers(help="Action to perform", dest="action")

    # Common arguments for all subcommands
    common_parser = ArgumentParser(add_help=False)
    common_parser.add_argument("-a",
                               "--architecture",
                               type=str,
                               default=machine(),
                               help="Architecture of virtual machine")
    common_parser.add_argument("-c",
                               "--cores",
                               type=int,
                               help="Number of cores virtual machine has")
    common_parser.add_argument("-m",
                               "--memory",
                               type=str,
                               help="Amount of memory virtual machine has")
    common_parser.add_argument("-n", "--name", type=str, help="Name of virtual machine")

    # Arguments for "list"
    list_parser = subparsers.add_parser("list",
                                        help="List virtual machines that can be run",
                                        parents=[common_parser])
    list_parser.set_defaults(func=list_vms)

    # Arguments for "setup"
    setup_parser = subparsers.add_parser("setup",
                                         help="Run virtual machine for first time",
                                         parents=[common_parser])
    setup_parser.add_argument("-i", "--iso", type=str, help="Path or URL of .iso to boot from")
    setup_parser.add_argument("-s",
                              "--size",
                              type=str,
                              default="50G",
                              help="Size of virtual machine disk image")
    setup_parser.set_defaults(func=setup_vm)

    # Arguments for "remove"
    remove_parser = subparsers.add_parser("remove",
                                          help="Remove virtual machine files",
                                          parents=[common_parser])
    remove_parser.set_defaults(func=remove_vm)

    # Arguments for "run"
    run_parser = subparsers.add_parser("run",
                                       help="Run virtual machine after setup",
                                       parents=[common_parser])
    run_parser.add_argument("-C", "--cmdline", type=str, help="Kernel cmdline string")
    run_parser.add_argument("-g",
                            "--gdb",
                            action="store_true",
                            help="Start QEMU with '-s -S' for debugging with gdb")
    run_parser.add_argument("-i", "--initrd", type=str, help="Path to initrd")
    run_parser.add_argument("-k",
                            "--kernel",
                            type=str,
                            help="Path to kernel image or kernel build directory")
    run_parser.set_defaults(func=run_vm)

    return parser.parse_args()


def quote_cmd(cmd):
    return ' '.join([quote(str(elem)) for elem in cmd])


def run_cmd(cmd):
    print(f"$ {quote_cmd(cmd)}")
    run(cmd, check=True)


def get_disk_img(vm_folder):
    return vm_folder.joinpath("disk.img")


def get_efi_img(cfg):
    arch = cfg["architecture"]
    vm_folder = cfg["vm_folder"]

    if arch == "aarch64":
        # Fedora location
        src = Path("/usr/share/edk2/aarch64/QEMU_EFI.fd")
        if not src.exists():
            # Arch Linux location
            src = Path("/usr/share/edk2-armvirt/aarch64/QEMU_EFI.fd")
            if not src.exists():
                raise FileNotFoundError(f"{src.name} could not be found!")

        dst = vm_folder.joinpath("efi.img")
        if not dst.exists():
            run_cmd(["truncate", "-s", "64m", dst])
            run_cmd(["dd", f"if={src}", f"of={dst}", "conv=notrunc"])

        return dst

    if arch == "x86_64":
        src = Path("/usr/share/edk2-ovmf/x64/OVMF_CODE.fd")

        if src.exists():
            return src

        raise FileNotFoundError(f"{src.name} could not be found!")

    raise NotImplementedError(f"get_efi_img() is not implemented for {arch}")


def get_efi_vars(cfg):
    arch = cfg["architecture"]
    vm_folder = cfg["vm_folder"]

    if arch == "aarch64":
        efivars = vm_folder.joinpath("efivars.img")
        if not efivars.exists():
            run_cmd(["truncate", "-s", "64m", efivars])
        return efivars

    if arch == "x86_64":
        src = Path("/usr/share/OVMF/x64/OVMF_VARS.fd")

        if src.exists():
            dst = vm_folder.joinpath(src.name)
            if not dst.exists():
                copyfile(src, dst)
            return dst

        raise FileNotFoundError(f"{src.name} could not be found!")

    raise NotImplementedError(f"get_efi_vars() is not implemented for {arch}")


def get_iso(cfg):
    arch = cfg["architecture"]
    iso_folder = cfg["iso_folder"]
    iso = cfg["iso"]

    if "http://" in iso or "https://" in iso:
        dst = iso_folder.joinpath(iso.split("/")[-1])
        if not dst.exists():
            iso_folder.mkdir(parents=True, exist_ok=True)
            run_cmd(["wget", "-c", "-O", dst, iso])
    else:
        dst = Path(iso)
        if not dst.exists():
            raise FileNotFoundError(f"{dst} specified but it is not found!")

    return dst


def default_qemu_arguments(cfg):
    arch = cfg["architecture"]
    cores = cfg["cores"]
    memory = cfg["memory"]
    vm_folder = cfg["vm_folder"]

    # QEMU binary
    qemu = [f"qemu-system-{arch}"]

    # No display
    qemu += ["-display", "none"]
    qemu += ["-serial", "mon:stdio"]

    # Firmware
    fw_str = "if=pflash,format=raw,file="
    efi_img = get_efi_img(cfg)
    efi_vars = get_efi_vars(cfg)
    qemu += ["-drive", f"{fw_str}{efi_img},readonly=on"]
    qemu += ["-drive", f"{fw_str}{efi_vars}"]

    # Hard drive
    disk_img = get_disk_img(vm_folder)
    qemu += ["-drive", f"if=virtio,format=qcow2,file={disk_img}"]

    # Machine (AArch64 only)
    if arch == "aarch64":
        qemu += ["-M", "virt"]

    # KVM acceleration
    if arch == machine():
        qemu += ["-cpu", "host"]
        qemu += ["-enable-kvm"]
    elif arch == "aarch64":
        # QEMU is horrifically slow with just '-cpu max'
        # https://lore.kernel.org/YlgVa+AP0g4IYvzN@lakrids/
        qemu += ["-cpu", "max,pauth-impdef=true"]

    # Memory
    qemu += ["-m", memory]
    qemu += ["-device", "virtio-balloon"]

    # Networking
    qemu += ["-nic", "user,model=virtio-net-pci,hostfwd=tcp::8022-:22"]

    # Number of processor cores
    qemu += ["-smp", cores]

    # RNG
    qemu += ["-object", "rng-random,filename=/dev/urandom,id=rng0"]
    qemu += ["-device", "virtio-rng-pci"]

    return qemu


def list_vms(cfg):
    arch = cfg["architecture"]
    arch_folder = cfg["arch_folder"]

    print(f"\nAvailable VMs for {arch}:\n")

    if arch_folder.exists():
        vm_list = listdir(arch_folder)
        if vm_list:
            print("\n".join(vm_list))
            return

    print("None")


def setup_vm(cfg):
    vm_folder = cfg["vm_folder"]
    size = cfg["size"]

    # Create folder
    remove(cfg)
    vm_folder.mkdir(parents=True, exist_ok=True)

    # Create efivars image
    get_efi_vars(cfg)

    # Create disk image
    qemu_img = ["qemu-img", "create", "-f", "qcow2", get_disk_img(vm_folder), size]
    run_cmd(qemu_img)

    # Download ISO image
    iso = get_iso(cfg)

    qemu = default_qemu_arguments(cfg)
    qemu += ["-device", "virtio-scsi-pci,id=scsi0"]
    qemu += ["-device", "scsi-cd,drive=cd"]
    qemu += ["-drive", f"if=none,format=raw,id=cd,file={iso}"]

    run_cmd(qemu)


def remove_vm(cfg):
    vm_folder = cfg["vm_folder"]
    if vm_folder.is_dir():
        rmtree(vm_folder)


def run_vm(cfg):
    arch = cfg["architecture"]
    cmdline = cfg["cmdline"]
    gdb = cfg["gdb"]
    initrd = cfg["initrd"]
    kernel = cfg["kernel"]
    vm_folder = cfg["vm_folder"]

    if not vm_folder.exists():
        raise FileNotFoundError(f"{vm_folder} does not exist, run 'setup' first?")

    qemu = default_qemu_arguments(cfg)

    if cmdline:
        qemu += ["-append", cmdline]
    if kernel:
        qemu += ["-kernel", kernel]
    if initrd:
        qemu += ["-initrd", initrd]
    if gdb:
        qemu += ["-s", "-S"]

    run_cmd(qemu)


def set_cfg(args):
    # Architecture
    arch = args.architecture

    # VM name
    if args.name:
        name = args.name
    else:
        if arch == "aarch64":
            name = "fedora"
        elif arch == "x86_64":
            name = "arch"
        else:
            raise NotImplementedError(f"Default VM name has not been defined for {arch}")

    # .iso for setup (so "iso" might not be in args)
    if hasattr(args, "iso") and args.iso:
        iso = args.iso
    else:
        if arch == "aarch64":
            ver = 36
            iso = f"https://download.fedoraproject.org/pub/fedora/linux/releases/{ver}/server/aarch64/iso/fedora-server-netinst-aarch64-{ver}-1.5.iso"
        elif arch == "x86_64":
            ver = "2022.06.01"
            iso = f"https://mirror.arizona.edu/archlinux/iso/{ver}/archlinux-{ver}-x86_64.iso"
        else:
            raise NotImplementedError(f"Default .iso has not been defined for {arch}")

    # Folder for files
    if "VM_FOLDER" in environ:
        base_folder = Path(environ["VM_FOLDER"])
    else:
        base_folder = Path(__file__).resolve().parent.joinpath("vm")
    arch_folder = base_folder.joinpath(arch)
    iso_folder = base_folder.joinpath("iso")
    vm_folder = arch_folder.joinpath(name)

    # Support for running custom kernel image (so "kernel" might not be in args)
    if hasattr(args, "kernel") and args.kernel:
        # Kernel is either a path or a kernel image
        kernel = Path(args.kernel)
        if kernel.is_dir():
            kernel_dir = kernel
            if arch == "aarch64":
                kernel = kernel.joinpath("arch/arm64/boot/Image")
            elif arch == "x86_64":
                kernel = kernel.joinpath("arch/x86/boot/bzImage")
            else:
                raise NotImplementedError(f"Default kernel has not been defined for {arch}")
        else:
            kernel_dir = None

        if not kernel.exists():
            raise FileNotFoundError(f"{kernel} could not be found!")

        if args.cmdline:
            cmdline = args.cmdline
        else:
            if arch == "aarch64":
                cmdline = "console=ttyAMA0 root=/dev/vda3 ro"
            elif arch == "x86_64":
                cmdline = "console=ttyS0 root=/dev/vda2 rw rootfstype=ext4"
            else:
                raise NotImplementedError(f"Default cmdline has not been defined for {arch}")

        if args.initrd:
            initrd = Path(args.initrd)
        else:
            if not kernel_dir:
                raise RuntimeError(
                    "Kernel image was supplied without initrd, cannot guess initrd path!")

            if arch == "aarch64":
                initrd = kernel_dir.joinpath("initramfs.img")
            elif arch == "x86_64":
                initrd = kernel_dir.joinpath("rootfs/initramfs.img")
            else:
                raise NotImplementedError(f"Default initrd has not been defined for {arch}")

        if not initrd.exists():
            raise FileNotFoundError(f"{initrd} could not be found!")
    else:
        cmdline = None
        initrd = None
        kernel = None

    # Size of disk image (only used for setup, so "size" might not exist in args)
    size = args.size if hasattr(args, "size") else None

    # Number of cores
    if args.cores:
        cores = args.cores
    else:
        if arch == machine():
            # When using KVM, we cannot use more than the maximum number of
            # cores. Default to either 8 cores or half the number of cores in
            # the machine, whichever is smaller
            cores = min(8, cpu_count() / 2)
        else:
            # For TCG, use 4 cores by default
            cores = 4
    # cores might be a float due to the division above
    # Convert it to an integer for QEMU:
    # qemu-system-x86_64: Parameter 'smp.cpus' expects integer
    cores = int(cores)

    # Amount of memory
    if args.memory:
        memory = args.memory
    else:
        # We consider half of the system's memory in gigabytes as available for
        # the virtual machine

        # Total amount of memory of a system in gigabytes (page size * pages / 1024^3)
        total_mem = sysconf("SC_PAGE_SIZE") * sysconf("SC_PHYS_PAGES") / (1024.**3)

        # Get the current exponent of the size of memory, as most computers
        # have a power of 2 amount of memory; if it is not (like 12GB), then
        # this calculation will just result in a slightly larger amount of
        # memory being allocated to the VM. If this is a problem, the user can
        # just specify the amount of memory.
        exp = round(log2(total_mem))

        # To get half of the amount of memory, shift by one less exponent
        avail_mem_for_vm = 1 << (exp - 1)

        # We cap the amount of memory at two times the number of cores (as that
        # is sufficient for compiling) or total amount of available VM memory
        # from the calculation above.
        memory = f"{int(min(cores * 2, avail_mem_for_vm))}G"

    # subprocess.run() expects cores to be a string:
    # TypeError: expected str, bytes or os.PathLike object, not int
    # This needs to happen after the min() call above to avoid:
    # TypeError: '<' not supported between instances of 'int' and 'str'
    cores = str(cores)

    cfg = {
        "architecture": arch,
        "arch_folder": arch_folder,
        "cmdline": cmdline,
        "cores": cores,
        "initrd": initrd,
        "iso_folder": iso_folder,
        "iso": iso,
        "kernel": kernel,
        "memory": memory,
        "name": name,
        "size": size,
        "vm_folder": vm_folder,
    }
    if hasattr(args, "gdb"):
        cfg["gdb"] = args.gdb
    return cfg


def main():
    args = parse_parameters()
    cfg = set_cfg(args)

    arch = cfg["architecture"]
    supported_arches = ["aarch64", "x86_64"]
    if not arch in supported_arches:
        raise NotImplementedError(f"{arch} is not currently supported!")

    args.func(cfg)


if __name__ == '__main__':
    main()
