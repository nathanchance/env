#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_gen_archconfig -d "Generate a configuration file for Arch Linux"
    for arg in $argv
        switch $arg
            case --cfi --cfi-permissive
                set -a config_args -e CFI_CLANG
                if test $arg = --cfi-permissive
                    set -a config_args -e CFI_PERMISSIVE
                end
            case -f --full
                set config full
            case -l --local
                set config local
            case -m --menuconfig
                set menuconfig true
            case linux-cfi linux-debug linux-mainline-'*' linux-next-'*'
                set pkg $arg
        end
    end

    switch $pkg
        case linux-mainline-'*'
            set gpg_key 79BE3E4300411886
        case linux-next-'*'
            set gpg_key 89F91C0A41D5C07A
    end
    if not gpg -k $gpg_key &>/dev/null
        gpg --receive-keys $gpg_key
    end

    set linux $ENV_FOLDER/pkgbuilds/$pkg
    set cfg $linux/config
    set src $linux/src/$pkg
    set src_cfg $src/.config

    pushd $linux; or return

    # Step 1: Download and extract files
    touch $cfg
    makepkg -Cdo --skipchecksums; or return
    rm $src_cfg

    # Step 2: Copy default Arch configuration
    crl 'https://github.com/archlinux/svntogit-packages/raw/ff9d62bffc4421979c855ebd87d94beaa81691d0/trunk/config' >$cfg

    # Step 3: Run olddefconfig
    kmake -C $src KCONFIG_CONFIG=$cfg olddefconfig

    # Step 4: Run localmodconfig if requested
    if test "$config" = local
        cp $cfg $src_cfg
        kmake -C $src localmodconfig
        cp $src_cfg $cfg
        # A few configs might need to stay around for various reasons, build them as modules
        $src/scripts/config \
            --file $cfg \
            -m BLK_DEV_LOOP \
            -m EDAC_AMD64 \
            -m EDAC_DECODE_MCE \
            -m TUN \
            -m USB_HID \
            --set-val BLK_DEV_LOOP_MIN_COUNT 0
        kmake -C $src KCONFIG_CONFIG=$cfg olddefconfig
    end

    # Step 5: Run through olddefconfig with Clang
    kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 olddefconfig

    # Step 6: Disable BTF debug info and enable ThinLTO
    $src/scripts/config \
        --file $cfg \
        -d DEBUG_INFO_BTF \
        -d LTO_NONE \
        -e LTO_CLANG_THIN \
        $config_args
    kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 olddefconfig

    # Step 7: Run menuconfig if additional options are needed
    if test "$menuconfig" = true
        kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 menuconfig
    end

    # Step 8: Update checksums
    updpkgsums

    popd
end
