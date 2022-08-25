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
    set -a patches https://lore.kernel.org/all/20220815062004.22920-1-pkshih@realtek.com/ # [PATCH] wifi: rtw88: fix uninitialized use of primary channel index
    set -a patches https://lore.kernel.org/all/20220825180607.2707947-1-nathan@kernel.org/ # [PATCH net-next] net/mlx5e: Do not use err uninitialized in mlx5e_rep_add_meta_tunnel_rule()
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    crl https://lore.kernel.org/all/CAFULd4bgdGosQ3byMW9S+ov0uDO9iK3jCmZ-fkZQbCGOpfUvXQ@mail.gmail.com/2-0001-smpboot-Fix-cpu_wait_death-for-early-cpu-death.patch | git am; or return # [PATCH] smpboot: Fix cpu_wait_death for early cpu death
    crl https://lore.kernel.org/all/Ywepr7C2X20ZvLdn@monkey/raw | sed -n '/>From /,$p' | sed 's/^>From /From /' | git am; or return # [PATCH] hugetlb: fix/remove uninitialized variable in remove_inode_hugepages

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
