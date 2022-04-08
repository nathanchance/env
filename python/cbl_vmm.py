#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor
# Description: Virtual machine manager for ClangBuiltLinux development

import argparse
import math
from pathlib import Path
import platform
import os
import shutil
import subprocess


def parse_parameters():
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(help="Action to perform", dest="action")

    # Common arguments for all subcommands
    common_parser = argparse.ArgumentParser(add_help=False)
    common_parser.add_argument("-a",
                               "--architecture",
                               type=str,
                               default=platform.machine(),
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
    setup_parser.set_defaults(func=setup)

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
    run_parser.set_defaults(func=run)

    return parser.parse_args()


def run_cmd(cmd):
    print("$ %s" % " ".join([str(element) for element in cmd]))
    subprocess.run(cmd, check=True)


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
                raise RuntimeError("{} could not be found!".format(src.name))

        dst = vm_folder.joinpath("efi.img")
        if not dst.exists():
            run_cmd(["truncate", "-s", "64m", dst])
            run_cmd(["dd", "if={}".format(src), "of={}".format(dst), "conv=notrunc"])

        return dst

    if arch == "x86_64":
        src = Path("/usr/share/edk2-ovmf/x64/OVMF_CODE.fd")

        if src.exists():
            return src

        raise RuntimeError("{} could not be found!".format(src.name))

    raise RuntimeError("get_efi_img() is not implemented for {}".format(arch))


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
                shutil.copyfile(src, dst)
            return dst

        raise RuntimeError("{} could not be found!".format(src.name))

    raise RuntimeError("get_efi_vars() is not implemented for {}".format(arch))


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
            raise RuntimeError("{} specified but it is not found!".format(dst))

    return dst


def default_qemu_arguments(cfg):
    arch = cfg["architecture"]
    cores = cfg["cores"]
    memory = cfg["memory"]
    vm_folder = cfg["vm_folder"]

    # QEMU binary
    qemu = ["qemu-system-{}".format(arch)]

    # No display
    qemu += ["-display", "none"]
    qemu += ["-serial", "mon:stdio"]

    # Firmware
    fw_str = "if=pflash,format=raw,file="
    efi_img = get_efi_img(cfg)
    efi_vars = get_efi_vars(cfg)
    qemu += ["-drive", "{}{},readonly=on".format(fw_str, efi_img)]
    qemu += ["-drive", "{}{}".format(fw_str, efi_vars)]

    # Hard drive
    disk_img = get_disk_img(vm_folder)
    qemu += ["-drive", "if=virtio,format=qcow2,file={}".format(disk_img)]

    # Machine (AArch64 only)
    if arch == "aarch64":
        qemu += ["-M", "virt"]

    # KVM acceleration
    if arch == platform.machine():
        qemu += ["-cpu", "host"]
        qemu += ["-enable-kvm"]
    elif arch == "aarch64":
        qemu += ["-cpu", "max"]

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


def setup(cfg):
    vm_folder = cfg["vm_folder"]
    size = cfg["size"]

    # Create folder
    if vm_folder.is_dir():
        shutil.rmtree(vm_folder)
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
    qemu += ["-drive", "if=none,format=raw,id=cd,file={}".format(iso)]

    run_cmd(qemu)


def run(cfg):
    arch = cfg["architecture"]
    cmdline = cfg["cmdline"]
    gdb = cfg["gdb"]
    initrd = cfg["initrd"]
    kernel = cfg["kernel"]

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
            raise RuntimeError("Default VM name has not been defined for {}".format(arch))

    # .iso for setup (so "iso" might not be in args)
    if hasattr(args, "iso") and args.iso:
        iso = args.iso
    else:
        if arch == "aarch64":
            ver = 35
            iso = "https://download.fedoraproject.org/pub/fedora/linux/releases/{0}/server/aarch64/iso/fedora-server-netinst-aarch64-{0}-1.2.iso".format(
                ver)
        elif arch == "x86_64":
            ver = "2022.04.05"
            iso = "https://mirror.arizona.edu/archlinux/iso/{0}/archlinux-{0}-x86_64.iso".format(
                ver)
        else:
            raise RuntimeError("Default .iso has not been defined for {}".format(arch))

    # Folder for files
    if "VM_FOLDER" in os.environ:
        base_folder = Path(os.environ["VM_FOLDER"])
    else:
        base_folder = Path(__file__).resolve().parent.joinpath("vm")
    iso_folder = base_folder.joinpath("iso")
    vm_folder = base_folder.joinpath(arch, name)

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
                raise RuntimeError("Default kernel has not been defined for {}".format(arch))
        else:
            kernel_dir = None

        if not kernel.exists():
            raise RuntimeError("{} could not be found!".format(kernel))

        if args.cmdline:
            cmdline = args.cmdline
        else:
            if arch == "aarch64":
                cmdline = "console=ttyAMA0 root=/dev/vda3 ro"
            elif arch == "x86_64":
                cmdline = "console=ttyS0 root=/dev/vda2 rw rootfstype=ext4"
            else:
                raise RuntimeError("Default cmdline has not been defined for {}".format(arch))

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
                raise RuntimeError("Default initrd has not been defined for {}".format(arch))

        if not initrd.exists():
            raise RuntimeError("{} could not be found!".format(initrd))
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
        if arch == platform.machine():
            # When using KVM, we cannot use more than the maximum number of
            # cores. Default to either 8 cores or half the number of cores in
            # the machine, whichever is smaller
            cores = min(8, os.cpu_count() / 2)
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
        total_mem = os.sysconf("SC_PAGE_SIZE") * os.sysconf("SC_PHYS_PAGES") / (1024.**3)

        # Get the current exponent of the size of memory, as most computers
        # have a power of 2 amount of memory; if it is not (like 12GB), then
        # this calculation will just result in a slightly larger amount of
        # memory being allocated to the VM. If this is a problem, the user can
        # just specify the amount of memory.
        exp = round(math.log2(total_mem))

        # To get half of the amount of memory, shift by one less exponent
        avail_mem_for_vm = 1 << (exp - 1)

        # We cap the amount of memory at two times the number of cores (as that
        # is sufficient for compiling) or total amount of available VM memory
        # from the calculation above.
        memory = "{}G".format(int(min(cores * 2, avail_mem_for_vm)))

    # subprocess.run() expects cores to be a string:
    # TypeError: expected str, bytes or os.PathLike object, not int
    # This needs to happen after the min() call above to avoid:
    # TypeError: '<' not supported between instances of 'int' and 'str'
    cores = str(cores)

    cfg = {
        "architecture": arch,
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
        raise RuntimeError("{} is not currently supported!".format(arch))

    args.func(cfg)


if __name__ == '__main__':
    main()
