#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function gen_localmodconfig -d "Generate a slimmed down configuration file for Arch Linux"
    for arg in $argv
        switch $arg
            case linux-mainline-llvm linux-next-llvm
                set pkg $arg
        end
    end

    set linux_llvm $ENV_FOLDER/pkgbuilds/$pkg
    set cfg $linux_llvm/config
    set src $linux_llvm/src/$pkg
    set src_cfg $src/.config

    pushd $linux_llvm; or return

    # Step 1: Download and extract files
    touch $cfg
    makepkg -Cdo; or return
    rm $src_cfg

    # Step 2: Copy configuration
    crl 'https://github.com/archlinux/svntogit-packages/raw/packages/linux/trunk/config' >$cfg

    # Step 3: Run olddefconfig
    kmake -C $src KCONFIG_CONFIG=$cfg olddefconfig

    # Step 4: Run localmodconfig
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

    # Step 5: Run through olddefconfig with Clang
    kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 olddefconfig

    # Step 6: Disable debug info and enable ThinLTO
    $src/scripts/config \
        --file $cfg \
        -d DEBUG_INFO \
        -d LTO_NONE \
        -e LTO_CLANG_THIN
    kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 olddefconfig

    popd
end
