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
    set -a patches https://lore.kernel.org/all/20230209124513.1341645-1-arnd@kernel.org/ # drm/amd/display: fix link_validation build failure
    set -a patches https://lore.kernel.org/all/20230208142508.3278406-1-edumazet@google.com/ # net: enable usercopy for skb_small_head_cache
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
