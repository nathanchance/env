#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function gen_vm_kernel_files -d "Generate files needed to boot local compiled kernels with cbl_vmm.py"
    # Make sure we are not running our own kernel, which might not have modules enabled
    if string match -qr '\(nathan@' (cat /proc/version)
        print_error "It seems like a non-stock kernel is booted?"
        return 1
    end

    # Make sure all modules the virtual machine might need are loaded (virtiofs, tun, overlayfs, etc)
    mount_host_folder; or return
    # For some reason, container sometimes fails to enter on first try on Alpine.
    dbxe -- true; or dbxe -- true; or return

    # Create kernel_files folder
    set kernel_folder $HOST_FOLDER/kernel_files
    mkdir -p $kernel_folder

    # Get cmdline and lsmod
    cat /proc/cmdline >$kernel_folder/cmdline
    lsmod >$kernel_folder/lsmod

    # Generate initrd
    gen_slim_initrd $kernel_folder
end
