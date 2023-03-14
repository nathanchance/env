#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c; or return

    set fd_src $CBL_BLD/fedora
    pushd $fd_src; or return

    # Update kernel
    git ru --prune origin; or return
    git rh origin/master

    # Patching
    set -a b4_patches https://lore.kernel.org/all/20230314-vmware-wuninitialized-v1-1-1bb4b0989758@kernel.org/ # drm/vmwgfx: Fix uninitialized use of dst_pitch in vmw_stdu_bo_cpu_commit()
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for patch in $crl_patches
        crl $patch | git am -3; or return
    end
    set -a ln_commits 3140716495946840a03cf3e7674bde26ea3cf3a3 # REPORTED: drm/rockchip: Avoid uninitialized use of possible_crtcs in vop2_create_crtcs()
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    for revert in $reverts
        git revert --no-edit $revert; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
