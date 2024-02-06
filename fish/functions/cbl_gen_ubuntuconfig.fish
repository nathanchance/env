#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_gen_ubuntuconfig -d "Generate a kernel .config from Ubuntu's configuration fragments"
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
        switch (uname -m)
            case aarch64
                set arch arm64
            case '*'
                set arch (uname -m)
        end
    end
    if not set -q no_werror
        set -a scripts_config_args \
            -e WERROR
    end
    switch $arch
        case aarch64
            set ubuntu_arch arm64
        case x86_64
            set ubuntu_arch amd64
        case '*'
            set ubuntu_arch $arch
    end

    set out (kbf)/$arch
    set cfg $out/.config

    remkdir $out

    set mainline_crack $NVME_SRC_FOLDER/mainline-crack
    if not test -d $mainline_crack
        git clone https://git.launchpad.net/~ubuntu-kernel-test/ubuntu/+source/linux/+git/mainline-crack $mainline_crack
    end
    git -C $mainline_crack ru -p; or return
    git -C $mainline_crack checkout (git -C $mainline_crack tag --sort -creatordate -l cod/mainline/v'*' | head -1); or return

    $mainline_crack/debian/scripts/misc/annotations \
        --arch $ubuntu_arch \
        --export \
        --file $mainline_crack/debian.master/config/annotations >$cfg

    scripts/config \
        --file $cfg \
        -d DEBUG_INFO \
        -d DEBUG_INFO_DWARF4 \
        --set-val FRAME_WARN 1500 \
        -d IMA_APPRAISE_MODSIG \
        -d MODULE_SIG \
        -d MODULE_SIG_ALL \
        -u MODULE_SIG_KEY \
        -d SECURITY_LOCKDOWN_LSM \
        -u SYSTEM_REVOCATION_KEYS \
        -u SYSTEM_TRUSTED_KEYS \
        -d UBSAN \
        -e DEBUG_INFO_NONE \
        -e LOCALVERSION_AUTO \
        $scripts_config_args
end
