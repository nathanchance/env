#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function install_arch_kernel -d "Install kernel for Arch Linux and reboot fully or via kexec"
    for arg in $argv
        switch $arg
            case -k --kexec
                set reboot kexec
            case -r --reboot
                set reboot reboot
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

    if set -q reboot
        if test $reboot = kexec
            switch $LOCATION
                case test-laptop-intel
                    print_warning "kexec is not safe on this platform, switching to full reboot..."
                    set reboot reboot
            end
        end

        switch $reboot
            case kexec
                if not command -q kexec
                    print_error "Cannot kexec without kexec-tools"
                    return 1
                end

                sudo kexec \
                    --load \
                    /boot/vmlinuz-$krnl \
                    --initrd=/boot/initramfs-$krnl.img \
                    --reuse-cmdline
                or return

            case reboot
                if not test -d /sys/firmware/efi
                    print_error "Expected to boot under UEFI?"
                    return 1
                end
                if not test -d /boot/loader/entries
                    print_error "Expected systemd-boot?"
                    return 1
                end

                set boot_conf /boot/loader/entries/$krnl.conf
                if not test -f $boot_conf
                    print_error "$boot_conf does not exist!"
                    return 1
                end

                sudo bootctl set-oneshot $krnl.conf
                or return
        end

        sudo systemctl $reboot
    end
end
