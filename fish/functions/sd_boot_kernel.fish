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
            case --when='*'
                set -a systemctl_args $arg
            case '*'
                if test $arg = linux
                    set krnl linux
                else
                    set krnl linux-(string replace 'linux-' '' $arg)
                end
        end
    end

    if not set -q krnl
        __print_error "Kernel is required!"
        return 1
    end

    sudo true
    or return

    switch $reboot
        case kexec
            if not command -q kexec
                __print_error "Cannot kexec without kexec-tools"
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
                __print_error "Not booted under UEFI?"
                return 1
            end

            set entries /boot/loader/entries
            if not test -d $entries
                __print_error "$entries not found, not using systemd-boot?"
                return 1
            end

            set conf $krnl.conf
            if not test -f $entries/$conf
                __print_error "$entries/$conf does not exist!"
                return 1
            end

            set -a systemctl_args --boot-loader-entry=$conf
    end

    sudo systemctl $reboot $systemctl_args
end
