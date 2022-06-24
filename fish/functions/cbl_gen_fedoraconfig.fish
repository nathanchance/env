#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_gen_fedoraconfig -d "Downloads and modifies Fedora's kernel configuration"
    for arg in $argv
        switch $arg
            case aarch64 amd64 arm64 x86_64
                set arch $arg
        end
    end
    if not set -q arch
        set arch (uname -m)
    end
    switch $arch
        case amd64
            set arch x86_64
        case arm64
            set arch aarch64
    end

    crl -o .config https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-$arch-fedora.config

    scripts/config \
        -d DEBUG_INFO \
        -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
        -d LTO_NONE \
        -e LOCALVERSION_AUTO \
        -e LTO_CLANG_THIN \
        -e WERROR \
        --set-val FRAME_WARN 1500 \
        --set-val NR_CPUS 256
end
