#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function sd_boot_kernel -d "Boot a kernel via full reboot or kexec using systemd"
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

    if test $reboot = kexec
        switch $LOCATION
            case test-laptop-intel
                print_warning "kexec is not safe on this platform, switching to full reboot..."
                set reboot reboot
        end
    end

    sudo true
    or return

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
                print_error "Not booted under UEFI?"
                return 1
            end

            set entries /boot/loader/entries
            if not test -d $entries
                print_error "$entries not found, not using systemd-boot?"
                return 1
            end

            set conf $krnl.conf
            if not test -f $entries/$conf
                print_error "$entries/$conf does not exist!"
                return 1
            end

            set -a reboot --boot-loader-entry=$conf
    end

    sudo systemctl $reboot
end
