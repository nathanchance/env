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
    set -a patches https://lore.kernel.org/all/20220922184525.3021522-1-zack@kde.org/ # kbuild: Add an option to skip vmlinux.bz2 in the rpm's
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    sed -i 's;if (sc->gfp_mask \& __GFP_ATOMIC);if (!(sc->gfp_mask \& __GFP_DIRECT_RECLAIM));g' drivers/gpu/drm/msm/msm_gem_shrinker.c
    git add drivers/gpu/drm/msm/msm_gem_shrinker.c
    git c -m "drm/msm/gem: Account for 'mm: discard __GFP_ATOMIC'

Link: https://lore.kernel.org/20220906210348.4744da42@canb.auug.org.au/"; or return

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
