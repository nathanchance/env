#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c; or return

    set fd_src $CBL_BLD/fedora
    pushd $fd_src; or return

    # Update and patch kernel
    git ru --prune origin; or return
    git rh origin/master

    # Patching
    set -a patches https://lore.kernel.org/all/20220825180607.2707947-1-nathan@kernel.org/ # [PATCH net-next] net/mlx5e: Do not use err uninitialized in mlx5e_rep_add_meta_tunnel_rule()
    set -a patches https://lore.kernel.org/all/20220829165450.217628-1-nathan@kernel.org/ # [PATCH] drm/msm/dsi: Remove use of device_node in dsi_host_parse_dt()
    set -a patches https://lore.kernel.org/all/20220830101237.22782-1-gal@nvidia.com/ # [PATCH net-next] net: ieee802154: Fix compilation error when CONFIG_IEEE802154_NL802154_EXPERIMENTAL is disabled
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    # Download and modify configuration
    git cl -q
    crl -o .config https://src.fedoraproject.org/rpms/kernel/raw/rawhide/f/kernel-aarch64-fedora.config
    scripts/config \
        -d DEBUG_INFO \
        -d DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT \
        -d LTO_NONE \
        -e CFI_CLANG \
        -e LOCALVERSION_AUTO \
        -e LTO_CLANG_THIN \
        -e SHADOW_CALL_STACK \
        -e WERROR \
        --set-val FRAME_WARN 1400 \
        --set-val NR_CPUS 16

    # Build kernel
    cbl_bld_krnl_rpm --no-config arm64; or return

    popd
end
