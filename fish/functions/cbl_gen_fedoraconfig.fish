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
    # Until Fedora has caught up with https://git.kernel.org/kees/c/ed2b548f1017586c44f50654ef9febb42d491f31
    crl https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-$arch-fedora.config | string replace CONFIG_UBSAN_SIGNED_WRAP CONFIG_UBSAN_INTEGER_WRAP >$cfg

    scripts/config \
        --file $cfg \
        -d DEBUG_INFO \
        -d DEBUG_INFO_DWARF4 \
        -d DEBUG_INFO_DWARF5 \
        -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
        -e DEBUG_INFO_NONE \
        -e IKCONFIG \
        -e IKCONFIG_PROC \
        -e LOCALVERSION_AUTO \
        --set-val FRAME_WARN 1500 \
        --set-val NR_CPUS 256 \
        $scripts_config_args
end
