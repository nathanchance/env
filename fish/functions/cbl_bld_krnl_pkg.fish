#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_bld_krnl_pkg -d "Build ClangBuiltLinux Arch Linux kernel package"
    in_container_msg -c; or return

    for arg in $argv
        switch $arg
            case -f --full -l --local -m --menuconfig
                set -a config_args $arg
            case -p --permissive
                set -a config_args --cfi-permissive
            case '*'cfi '*'debug '*'mainline'*' '*'next'*'
                set pkg linux-(string replace 'linux-' '' $arg)
        end
    end
    if not set -q pkg
        set pkg linux-mainline-llvm
    end

    set pkgroot $ENV_FOLDER/pkgbuilds/$pkg

    pushd $pkgroot; or return

    # Prerequisite: Clean up old kernels
    rm -- *.tar.zst

    # Generate .config
    if test $pkg = linux-cfi
        set -a config_args --cfi
    end
    cbl_gen_archconfig $config_args $pkg; or return

    # Update the pkgver if using a local tree
    if grep -q "file://" PKGBUILD
        cbl_upd_krnl_pkgver (basename $PWD)
    end

    # Build the kernel
    command makepkg -C; or return

    echo Run
    printf '\n\t$ sudo fish -c "pacman -U %s; and bootctl set-oneshot %s.conf; and reboot"\n\n' (realpath -- *.tar.zst | string replace $ENV_FOLDER \$ENV_FOLDER) $pkg
    echo "to install and use new kernel."

    popd
end
