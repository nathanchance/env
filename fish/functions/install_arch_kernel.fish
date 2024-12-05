#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function install_arch_kernel -d "Install kernel for Arch Linux and reboot fully or via kexec"
    for arg in $argv
        switch $arg
            case -k --kexec -r --reboot
                set sd_boot_arg $arg
            case '*'
                set krnl linux-(string replace 'linux-' '' $arg)
        end
    end

    if not set -q krnl
        print_error "Kernel is required!"
        return 1
    end

    # Attempt to look for kernel. If there is one in /tmp, use that, as it means
    # it has been downloaded from another machine. Otherwise, look if there is a
    # package in the build folder or pkgbuild folder within the build folder.
    for search in /tmp (tbf $krnl){,/pkgbuild}
        if test -d $search
            # Ignore packages for headers, we do not build out of tree kernel
            # modules, so they are not needed.
            fd -e tar.zst -u $krnl $search | string match -rv headers | read -a krnl_pkg
            if test -n "$krnl_pkg"
                if test (count $krnl_pkg) = 1
                    break
                else
                    print_error "Ambiguous kernels found: $krnl_pkg"
                    return 1
                end
            end
        end
    end
    if test -z "$krnl_pkg"
        print_error "Could not find kernel package for $krnl!"
        return 1
    end

    sudo true
    or return

    sudo pacman -U --noconfirm $krnl_pkg
    or return

    if set -q sd_boot_arg
        sd_boot_kernel $sd_boot_arg $krnl
    end
end
