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
                    -e CFI \
                    -e CFI_CLANG \
                    -e SHADOW_CALL_STACK
                if test $arg = --cfi-permissive
                    set -a scripts_config_args \
                        -e CFI_PERMISSIVE
                end
            case --debug
                set debug true
            case --lto
                if string match -qr LTO_CLANG_THIN_DIST <arch/Kconfig
                    set thin_lto_cfg LTO_CLANG_THIN_DIST
                else
                    set thin_lto_cfg LTO_CLANG_THIN
                end
                set -a scripts_config_args \
                    -d LTO_NONE \
                    -e $thin_lto_cfg
            case --no-debug
                set debug false
            case --no-werror
                set no_werror true
            case --slim-arm64-platforms
                set slim_arm64_platforms true
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
        if test "$arch" = aarch64; and contains CFI $scripts_config_args
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
    if test "$arch" = aarch64; and set -q slim_arm64_platforms
        string match -gr '^config (.*)$' <arch/arm64/Kconfig.platforms | while read -l val
            # While Honeycomb does not currently use device tree, we cannot nix
            # Layerscape support for two reasons:
            # 1. Honeycomb may get updated firmware that uses device tree
            #    instead of ACPI
            # 2. Several drivers that it uses depend on this configuration
            if test "$val" = ARCH_LAYERSCAPE
                continue
            end
            set -a scripts_config_args -d $val
        end
    end

    # Handle https://git.kernel.org/next/linux-next/c/e3ec97c3abaf2fb68cc755cae3229288696b9f3d
    # until addressed in the upstream Fedora configuration
    set -a scripts_config_args -e HYPERV

    if not set -q out
        set out (tbf)
    end
    set cfg $out/.config

    remkdir $out
    crl -o $cfg https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-$arch-fedora.config
    # sanity check configuration and fallback to local copy if it is not valid
    if string match -qr '<!DOCTYPE html>' <$cfg; or string match -qr '<html>' <$cfg
        cp -v $CBL_LKT/configs/fedora/$arch.config $cfg
    end

    scripts/config \
        --file $cfg \
        -e IKCONFIG \
        -e IKCONFIG_PROC \
        -e LOCALVERSION_AUTO \
        --set-str CONFIG_EFI_SBAT_FILE '' \
        --set-val FRAME_WARN 1600 \
        --set-val NR_CPUS 256 \
        $scripts_config_args
end
