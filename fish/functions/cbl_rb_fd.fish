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
    set -a patches https://lore.kernel.org/all/20221004232359.285685-1-nathan@kernel.org/ # fs/ntfs3: Don't use uni1 uninitialized in ntfs_d_compare()
    set -a patches https://lore.kernel.org/all/20221024151201.2215380-1-nathan@kernel.org/ # coresight: cti: Remove unused variables in cti_{dis,en}able_hw()
    set -a patches https://lore.kernel.org/all/20221024151953.2238616-1-nathan@kernel.org/ # drm/amdgpu: Fix uninitialized warning in mmhub_v2_0_get_clockgating()
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
