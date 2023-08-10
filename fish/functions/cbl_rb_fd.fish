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
    set -a b4_patches https://lore.kernel.org/all/20230724121934.1406807-1-arnd@kernel.org/ # btrfs: remove unused pages_processed variable
    set -a b4_patches https://lore.kernel.org/all/20230731123625.3766-1-christian.koenig@amd.com/ # drm/exec: use unique instead of local label
    set -a b4_patches https://lore.kernel.org/all/(seq 1 4)-v2-d2762acaf50a+16d-iommu_group_locking2_jgg@nvidia.com/ # Fix device_lock deadlock on two probe() paths
    set -a b4_patches https://lore.kernel.org/all/20230809114216.4078-1-aweber.kernel@gmail.com/ # backlight: lp855x: Drop ret variable in brightness change function
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for patch in $crl_patches
        crl $patch | git am -3; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
