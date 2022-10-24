#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_rb_pi -d "Rebase Raspberry Pi kernel on latest linux-next"
    in_container_msg -c; or return

    set pi_src $CBL_BLD/rpi

    for arg in $argv
        switch $arg
            case -s --skip-mainline
                set skip_mainline true
        end
    end

    pushd $pi_src; or return

    git ru; or return

    git rh origin/master

    # Patching
    set -a patches https://lore.kernel.org/all/20221014201354.3190007-2-ndesaulniers@google.com/ # ARM: remove lazy evaluation in Makefile
    set -a patches https://lore.kernel.org/all/20221014201354.3190007-3-ndesaulniers@google.com/ # ARM: use .arch directives instead of assembler command line flags
    set -a patches https://lore.kernel.org/all/20221014201354.3190007-4-ndesaulniers@google.com/ # ARM: only use -mtp=cp15 for the compiler
    set -a patches https://lore.kernel.org/all/20221014201354.3190007-5-ndesaulniers@google.com/ # ARM: pass -march= only to compiler
    set -a patches https://lore.kernel.org/all/20221024151201.2215380-1-nathan@kernel.org/ # coresight: cti: Remove unused variables in cti_{dis,en}able_hw()
    for patch in $patches
        b4 am -l -o - -P _ -s $patch | git am; or return
    end
    crl https://lore.kernel.org/all/20221022163356.f5e08eeefe66fc71845be861@linux-foundation.org/ | git ap; or return
    git ac -m "fix pgmap_request_folio() stub return type

Link: https://lore.kernel.org/20221022233402.ED5F4C433D7@smtp.kernel.org/"

    # Regenerate defconfigs
    for arch in arm arm64
        switch $arch
            case arm
                set config multi_v7_defconfig
            case arm64
                set config defconfig
        end
        kmake ARCH=$arch HOSTLDFLAGS=-fuse-ld=lld LLVM=1 O=.build/$arch $config savedefconfig; or return
        mv -v .build/$arch/defconfig arch/$arch/configs/$config
    end
    git ac -m "ARM: configs: savedefconfig"

    # Tailscale configs
    for cfg_file in arch/arm/configs/multi_v7_defconfig arch/arm64/configs/defconfig
        scripts/config \
            --file $cfg_file \
            -e IP_NF_IPTABLES \
            -e NETFILTER \
            -e NETFILTER_NETLINK \
            -e NETFILTER_XTABLES \
            -e NETFILTER_XT_MATCH_COMMENT \
            -e NETFILTER_XT_MARK \
            -e NETFILTER_XT_TARGET_MASQUERADE \
            -e NF_CONNTRACK \
            -e NF_NAT \
            -e NF_TABLES \
            -e NF_TABLES_IPV4 \
            -e NF_TABLES_IPV6 \
            -e NFT_COMPAT \
            -e NFT_NAT \
            -e TUN
    end

    # arm64 hardening
    scripts/config \
        --file arch/arm64/configs/defconfig \
        -d LTO_NONE \
        -e CFI_CLANG \
        -e LTO_CLANG_THIN \
        -e SHADOW_CALL_STACK

    # Disable DEBUG_INFO for smaller builds
    if grep -q "config DEBUG_INFO_NONE" lib/Kconfig.debug
        set sc_args -e DEBUG_INFO_NONE
    else
        set sc_args -d DEBUG_INFO
    end
    # Always enable -Werror
    set -a sc_args -e WERROR
    # Shut up -Wframe-larger-than
    set -a sc_args --set-val FRAME_WARN 0
    for cfg in arch/arm/configs/multi_v7_defconfig arch/arm64/configs/defconfig
        scripts/config --file $cfg $sc_args
    end

    # Ensure configs are run through savedefconfig before committing
    for arch in arm arm64
        switch $arch
            case arm
                set config multi_v7_defconfig
            case arm64
                set config defconfig
        end
        kmake ARCH=$arch HOSTLDFLAGS=-fuse-ld=lld LLVM=1 O=.build/$arch $config savedefconfig; or return
        mv -v .build/$arch/defconfig arch/$arch/configs/$config
    end
    git ac -m "ARM: configs: Update defconfigs"

    git am $GITHUB_FOLDER/patches/linux-misc/0001-ARM-dts-bcm2-711-837-Disable-the-display-pipeline.patch; or return

    for arch in arm arm64
        ../pi-scripts/build.fish $arch; or return
    end

    if test "$skip_mainline" != true
        if not git pll --no-edit mainline master
            rg "<<<<<<< HEAD"; and return
            for arch in arm arm64
                ../pi-scripts/build.fish $arch; or return
            end
            git aa
            git c --no-edit; or return
        end

        for arch in arm arm64
            ../pi-scripts/build.fish $arch; or return
        end
    end

    popd
end
