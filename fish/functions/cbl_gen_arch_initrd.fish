#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_gen_arch_initrd -d "Build initramfs with mkinitcpio for Arch Linux systems"
    in_tree kernel; or return

    set rel_file include/config/kernel.release
    if not test -f $rel_file
        print_error "$rel_file could not be found?"
        return 1
    end

    set rootfs $PWD/rootfs
    if not test -d $rootfs
        print_error "$rootfs does not exist, run 'make modules_install'?"
        return 1
    end

    mkinitcpio \
        -g $rootfs/initramfs.img \
        -k (cat $rel_file) \
        -r $rootfs \
        -S autodetect \
        -t $rootfs
end
