#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_gen_ubuntuconfig -d "Generate a kernel .config from Ubuntu's configuration fragments"
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
        case aarch64
            set ubuntu_arch arm64
        case x86_64
            set ubuntu_arch amd64
        case '*'
            set ubuntu_arch $arch
    end

    set out .build/$arch
    set cfg $out/.config

    rm -fr $out
    mkdir -p $out

    for file in config.common.ubuntu $ubuntu_arch/config.{common.$ubuntu_arch,flavour.generic}
        crl "https://git.launchpad.net/~ubuntu-kernel-test/ubuntu/+source/linux/+git/mainline-crack/plain/debian.master/config/$file?h=cod/mainline/v5.16-rc8"
    end >$cfg

    scripts/config \
        --file $cfg \
        -d DEBUG_INFO \
        --set-val FRAME_WARN 1500 \
        -d IMA_APPRAISE_MODSIG \
        -d MODULE_SIG \
        -d MODULE_SIG_ALL \
        -u MODULE_SIG_KEY \
        -d SECURITY_LOCKDOWN_LSM \
        -u SYSTEM_REVOCATION_KEYS \
        -u SYSTEM_TRUSTED_KEYS \
        -d UBSAN \
        -e WERROR
end
