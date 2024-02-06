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
            case --lto
                set -a scripts_config_args \
                    -d LTO_NONE \
                    -e LTO_CLANG_THIN
            case --no-werror
                set no_werror true
            case -u --ubsan-bounds
                set -a scripts_config_args \
                    -e UBSAN \
                    -e UBSAN_BOUNDS \
                    -d UBSAN_ALIGNMENT \
                    -d UBSAN_BOOL \
                    -d UBSAN_DIV_ZERO \
                    -d UBSAN_ENUM \
                    -d UBSAN_SHIFT \
                    -d UBSAN_UNREACHABLE
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

    set out (tbf)
    set cfg $out/.config

    remkdir $out
    crl -o $cfg https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-$arch-fedora.config

    scripts/config \
        --file $cfg \
        -d DEBUG_INFO \
        -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
        -e LOCALVERSION_AUTO \
        --set-val FRAME_WARN 1500 \
        --set-val NR_CPUS 256 \
        $scripts_config_args
end
