#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

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
    command makepkg -Cdo --skipchecksums; or return
    rm $src_cfg

    # Step 2: Copy default Arch configuration and set a few options
    crl 'https://github.com/archlinux/svntogit-packages/raw/packages/linux/trunk/config' >$cfg
    $src/scripts/config \
        --file $cfg \
        -e WERROR \
        -m DRM

    # Step 3: Run olddefconfig
    podcmd kmake -C $src KCONFIG_CONFIG=$cfg olddefconfig

    # Step 4: Run localmodconfig if requested
    if test "$config" = local
        cp $cfg $src_cfg
        podcmd kmake -C $src localmodconfig
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
        podcmd kmake -C $src KCONFIG_CONFIG=$cfg olddefconfig
    end

    # Step 5: Run through olddefconfig with Clang
    podcmd kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 olddefconfig

    # Step 6: Enable ThinLTO
    $src/scripts/config \
        --file $cfg \
        -d LTO_NONE \
        -e LTO_CLANG_THIN \
        $config_args
    podcmd kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 olddefconfig

    # Step 7: Run menuconfig if additional options are needed
    if test "$menuconfig" = true
        podcmd kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 menuconfig
    end

    # Step 8: Update checksums
    updpkgsums

    popd
end
