#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_bld_krnl_pkg -d "Build ClangBuiltLinux Arch Linux kernel package"
    set fish_trace 1

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

    pushd $ENV_FOLDER/pkgbuilds/$pkg; or return

    # Prerequisite: Clean up old kernels
    rm -- *.tar.zst

    # Generate .config
    if test $pkg = linux-cfi
        set -a config_args --cfi
    end
    cbl_gen_archconfig $config_args $pkg

    # Update the pkgver if using a local tree
    if grep -q "file://" PKGBUILD
        cbl_upd_krnl_pkgver (basename $PWD)
    end

    # Build the kernel
    makepkg -C; or return

    set -e fish_trace
    echo Run
    printf '\n\t$ yay -U %s\n\n' (readlink -f -- *.tar.zst | perl -pe 's/\n/ /')
    echo "to install new kernel"

    popd
end
