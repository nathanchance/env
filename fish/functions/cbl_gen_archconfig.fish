#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_gen_archconfig -d "Generate a configuration file for Arch Linux"
    in_container_msg -c; or return

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
            case --lto
                set -a config_args \
                    -d LTO_NONE \
                    -e LTO_CLANG_THIN
            case -m --menuconfig
                set menuconfig true
            case linux-debug linux-mainline-'*' linux-next-'*'
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

    # Step 2: Copy default Arch configuration and set a few options
    crl https://github.com/archlinux/svntogit-packages/raw/packages/linux/trunk/config >$cfg
    $src/scripts/config \
        --file $cfg \
        -d LOCALVERSION_AUTO \
        -e DEBUG_INFO_DWARF5 \
        -e WERROR \
        -m DRM
    # Enable MGLRU. Remove when 6.1 is in the Arch Linux repos, as it will
    # likely be enabled then.
    $src/scripts/config \
        --file $cfg \
        -e LRU_GEN \
        -e LRU_GEN_ENABLED
    # https://git.kernel.org/linus/456ca88d8a5258fc66edc42a10053ac8473de2b1
    # Remove when 6.1 is in the Arch Linux repos.
    $src/scripts/config \
        --file $cfg \
        -e X86_AMD_PSTATE

    # Step 3: Run olddefconfig
    kmake -C $src KCONFIG_CONFIG=$cfg olddefconfig

    # Step 4: Run localmodconfig if requested
    if test "$config" = local
        cp $cfg $src_cfg
        kmake -C $src localmodconfig
        cp $src_cfg $cfg
    end

    # Step 5: Run through olddefconfig with Clang
    kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 olddefconfig

    # Step 6: Enable ThinLTO or CFI
    if test -n "$config_args"
        $src/scripts/config \
            --file $cfg \
            $config_args
        kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 olddefconfig
    end

    # Step 7: Run menuconfig if additional options are needed
    if test "$menuconfig" = true
        kmake -C $src KCONFIG_CONFIG=$cfg LLVM=1 LLVM_IAS=1 menuconfig
    end

    # Step 8: Update checksums
    updpkgsums

    popd
end
