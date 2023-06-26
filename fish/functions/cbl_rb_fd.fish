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
    # https://lore.kernel.org/CA+G9fYtKCZeAUTtwe69iK8Xcz1mOKQzwcy49wd+imZrfj6ifXA@mail.gmail.com/
    # c3b60ab7a4dff6e6e608e685b70ddc3d6b2aca81 is the real problem but it is easier to just revert
    # the merge that brought in the whole series.
    set -a reverts 712557f210723101717570844c95ac0913af74d7 # Merge branch 'ptp-adjphase-cleanups'
    # https://lore.kernel.org/8c7f9abd-4f84-7296-2788-1e130d6304a0@kernel.org/
    set -a reverts 3f5f118bb657f94641ea383c7c1b8c09a5d46ea2 # af_unix: Call scm_recv() only after scm_set_cred().
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
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
