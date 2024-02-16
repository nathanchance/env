#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_rb_pi -d "Rebase Raspberry Pi kernel on latest linux-next"
    in_container_msg -c; or return

    set pi_src $CBL_SRC_P/rpi
    set pi_out (tbf $pi_src)
    # Used to include arm64 but that has since been cut over to Fedora.
    # arm64 support is left around in case a future reason to revert
    # back to Debian is discovered.
    set pi_arches arm

    for arg in $argv
        switch $arg
            case -s --skip-mainline
                set skip_mainline true
        end
    end

    begin
        pushd $pi_src
        and git ru -p origin
    end
    or return

    git rh origin/master

    # Patching
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
    set -a b4_patches https://lore.kernel.org/all/20240216163259.1927967-1-arnd@kernel.org/ # firmware: arm_scmi: avoid returning uninialized data
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch
        or begin
            set ret $status
            git ama
            return $ret
        end
    end
    for patch in $crl_patches
        crl $patch | git am -3
        or begin
            set ret $status
            git ama
            return $ret
        end
    end
    for hash in $ln_commits
        git -C $CBL_SRC_P/linux-next fp -1 --stdout $hash | git am
        or begin
            set ret $status
            git ama
            return $ret
        end
    end
    for patch in $am_patches
        git am -3 $patch
        or begin
            set ret $status
            git ama
            return $ret
        end

    end

    for arch in $pi_arches
        switch $arch
            case arm
                set config multi_v7_defconfig
            case arm64
                set config defconfig
        end
        set -a cfg_files arch/$arch/configs/$config
    end

    # Regenerate defconfigs
    for cfg_file in $cfg_files
        string split -f 2 / $cfg_file | read -l arch
        kmake ARCH=$arch HOSTLDFLAGS=-fuse-ld=lld LLVM=1 O=$pi_out/$arch (basename $cfg_file) savedefconfig
        or return
        mv -v $pi_out/$arch/defconfig $cfg_file
    end
    git ac -m "ARM: configs: savedefconfig"

    # Docker configuration for ARM
    if contains arm $pi_arches
        scripts/config \
            --file arch/arm/configs/multi_v7_defconfig \
            -e BLK_CGROUP \
            -e BPF_SYSCALL \
            -e BRIDGE_VLAN_FILTERING \
            -e CGROUP_BPF \
            -e CGROUP_CPUACCT \
            -e CGROUP_DEVICE \
            -e CGROUP_FREEZER \
            -e CGROUP_PERF \
            -e CGROUP_PIDS \
            -e CGROUP_SCHED \
            -e CPUSETS \
            -e EXT4_FS_POSIX_ACL \
            -e FAIR_GROUP_SCHED \
            -e MEMCG \
            -e NAMESPACES \
            -e POSIX_MQUEUE \
            -e USER_NS \
            -e VLAN_8021Q \
            -m BRIDGE \
            -m BRIDGE_NETFILTER \
            -m IP_NF_FILTER \
            -m IP_NF_NAT \
            -m IP_NF_TARGET_MASQUERADE \
            -m IP_VS \
            -m NETFILTER_XT_MATCH_ADDRTYPE \
            -m NETFILTER_XT_MATCH_CONNTRACK \
            -m NETFILTER_XT_MATCH_IPVS \
            -m OVERLAY_FS \
            -m VETH
    end

    # Configs for binfmt_misc (Bookworm and newer) and Tailscale
    for cfg_file in $cfg_files
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
            -e TUN \
            -m BINFMT_MISC
    end

    # arm64 hardening
    if contains arm64 $pi_arches
        scripts/config \
            --file arch/arm64/configs/defconfig \
            -d LTO_NONE \
            -e CFI_CLANG \
            -e LTO_CLANG_THIN \
            -e SHADOW_CALL_STACK
    end

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
    for cfg in $cfg_files
        scripts/config --file $cfg $sc_args
    end

    # Ensure configs are run through savedefconfig before committing
    for cfg_file in $cfg_files
        string split -f 2 / $cfg_file | read -l arch
        kmake ARCH=$arch HOSTLDFLAGS=-fuse-ld=lld LLVM=1 O=$pi_out/$arch (basename $cfg_file) savedefconfig
        or return
        mv -v $pi_out/$arch/defconfig $cfg_file
    end
    git ac -m "ARM: configs: Update defconfigs"

    git am $GITHUB_FOLDER/patches/linux-misc/0001-ARM-dts-bcm2-711-837-Disable-the-display-pipeline.patch
    or return

    for arch in $pi_arches
        $GITHUB_FOLDER/pi-scripts/build.fish $arch
        or return
    end

    if test "$skip_mainline" != true
        if not git pll --no-edit mainline master
            rg "<<<<<<< HEAD"
            and return

            for arch in $pi_arches
                $GITHUB_FOLDER/pi-scripts/build.fish $arch
                or return
            end
            git aa
            git c --no-edit
            or return
        end

        for arch in $pi_arches
            $GITHUB_FOLDER/pi-scripts/build.fish $arch
            or return
        end
    end

    popd
end
