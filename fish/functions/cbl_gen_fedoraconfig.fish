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

    crl -o .config https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-$arch-fedora.config

    # Remove once Fedora has updated to 6.1
    # https://git.kernel.org/soc/soc/c/96796c914b841a7658e9617b1325175b4d02c574
    # https://git.kernel.org/soc/soc/c/566e373fe047f35be58d8a97061275be4dcb4132
    set -a scripts_config_args \
        -e ARCH_BCM \
        -e ARCH_NXP

    scripts/config \
        -d DEBUG_INFO \
        -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
        -e LOCALVERSION_AUTO \
        --set-val FRAME_WARN 1500 \
        --set-val NR_CPUS 256 \
        $scripts_config_args
end
