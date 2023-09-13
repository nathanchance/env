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
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
    set -a b4_patches https://lore.kernel.org/all/20230913-ctime-v1-1-c6bc509cbc27@kernel.org/ # overlayfs: set ctime when setting mtime and atime
    set -a b4_patches https://lore.kernel.org/all/20230913-fix-wuninitialized-dm_helpers_dp_mst_send_payload_allocation-v1-1-2d1b0a3ef16c@kernel.org/ # drm/amd/display: Fix -Wuninitialized in dm_helpers_dp_mst_send_payload_allocation()
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for patch in $crl_patches
        crl $patch | git am -3; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    # https://github.com/ClangBuiltLinux/linux/issues/1923
    set -a am_patches $GITHUB_FOLDER/patches/linux-next/cbl-1923/00{0{1,3,4,5,6},1{0,1}}-*.patch
    for patch in $am_patches
        git am -3 $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
