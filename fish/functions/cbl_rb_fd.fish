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
    set -a patches https://lore.kernel.org/all/20221020135709.1549086-1-colin.i.king@gmail.com/ # wifi: rtl8xxxu: Fix reads of uninitialized variables hw_ctrl_s1, sw_ctrl_s1
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
