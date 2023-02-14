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
    set -a patches https://lore.kernel.org/all/20230213101220.3821689-1-arnd@kernel.org/ # cxl: avoid returning uninitialized error code
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    # https://lore.kernel.org/Y+rSXg14z1Myd8Px@dev-arch.thelio-3990X/
    set -a reverts 31b4b6730fd4f5d503c9f23619c920ce7b794754 # driver core: add error handling for devtmpfs_create_node()
    set -a reverts 90a9d5ff225267b3376f73c19f21174e3b6d7746 # devtmpfs: add debug info to handle()
    for revert in $reverts
        git revert --no-edit $revert; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
