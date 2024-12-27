#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_gen_vm_boot_files -d "Generate files needed to boot local compiled kernels with cbl_vmm.py"
    # Make sure we are not running our own kernel, which might not have modules enabled
    if string match -qr '\(nathan@' (cat /proc/version)
        print_error "It seems like a non-stock kernel is booted?"
        return 1
    end

    # Make sure all modules the virtual machine might need are loaded (virtiofs, tun, overlayfs, etc)
    ls $HOST_FOLDER 1>/dev/null; or return
    if not using_nspawn
        # For some reason, container sometimes fails to enter on first try on Alpine.
        dbxe -- true; or dbxe -- true; or return
    end

    # Create kernel_files folder
    set kernel_folder $HOST_FOLDER/kernel_files
    mkdir -p $kernel_folder

    # Get cmdline and lsmod
    cat /proc/cmdline >$kernel_folder/cmdline
    lsmod >$kernel_folder/lsmod

    # Generate initrd
    gen_slim_initrd $kernel_folder
end
