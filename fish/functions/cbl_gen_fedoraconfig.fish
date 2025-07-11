#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_gen_fedoraconfig -d "Downloads and modifies Fedora's kernel configuration"
    for arg in $argv
        switch $arg
            case aarch64 amd64 arm64 x86_64
                set arch $arg
            case --cfi --cfi-permissive
                set -a scripts_config_args \
                    -e CFI_CLANG \
                    -e SHADOW_CALL_STACK
                if test $arg = --cfi-permissive
                    set -a scripts_config_args \
                        -e CFI_PERMISSIVE
                end
            case --debug
                set debug true
            case --lto
                set -a scripts_config_args \
                    -d LTO_NONE \
                    -e LTO_CLANG_THIN
            case --no-debug
                set debug false
            case --no-werror
                set no_werror true
        end
    end
    if not set -q arch
        set arch (uname -m)
    end
    if not set -q no_werror
        set -a scripts_config_args \
            -e WERROR
    end
    switch $arch
        case amd64
            set arch x86_64
        case arm64
            set arch aarch64
    end
    if not set -q debug
        # BTF is unlikely to be useful in this scenario so disable it
        # https://lore.kernel.org/CAADnVQ+jNQyC=RcoiwDXeHj9y6CGzr322scz_8uGwCDVx-Od4Q@mail.gmail.com/
        if test "$arch" = aarch64; and contains CFI_CLANG $scripts_config_args
            set debug false
        else
            set debug true
        end
    end
    if test "$debug" = false # debug info is on by default in Fedora
        set -a scripts_config_args \
            -d DEBUG_INFO \
            -d DEBUG_INFO_DWARF4 \
            -d DEBUG_INFO_DWARF5 \
            -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
            -e DEBUG_INFO_NONE
    end
    # https://lore.kernel.org/20250317174840.GA1451320@ax162/
    if contains LTO_CLANG_THIN $scripts_config_args; and git merge-base --is-ancestor 6ee149f61bcce39692f0335a01e99355d4cec8da HEAD
        set -a scripts_config_args -d FORTIFY_KUNIT_TEST
    end

    set out (tbf)
    set cfg $out/.config

    remkdir $out
    crl -o $cfg https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-$arch-fedora.config
    # sanity check configuration and fallback to local copy if it is not valid
    if string match -qr '<!DOCTYPE html>' <$cfg
        cp -v $CBL_LKT/configs/fedora/$arch.config $cfg
    end

    scripts/config \
        --file $cfg \
        -e IKCONFIG \
        -e IKCONFIG_PROC \
        -e LOCALVERSION_AUTO \
        --set-val FRAME_WARN 1500 \
        --set-val NR_CPUS 256 \
        $scripts_config_args
end
