#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function gen_vm_kernel_files -d "Generate files needed to boot local compiled kernels with cbl_vmm.py"
    # Make sure all modules the virtual machine might need are loaded (virtiofs, tun, overlayfs, etc)
    mount_host_folder; or return
    # For some reason, container sometimes fails to enter on first try on Alpine.
    dbxe -- true; or dbxe -- true; or return

    # Generate initrd
    set kernel_folder $HOST_FOLDER/kernel_files
    mkdir -p $kernel_folder
    gen_slim_initrd $kernel_folder; or return

    # Get cmdline and lsmod
    cat /proc/cmdline >$kernel_folder/cmdline
    lsmod >$kernel_folder/lsmod
end
