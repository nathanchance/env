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
    set -a reverts a8ffe235b11e8a7274c4aa848a1371c315924974 # bcachefs: trans_for_each_update() now declares loop iter
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
    set -a b4_patches https://lore.kernel.org/all/20231212171044.1108464-1-jtornosm@redhat.com/ # rpm-pkg: simplify installkernel %post
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    set -a crl_patches 'https://evilpiepirate.org/git/bcachefs.git/patch/?id=caa480b52367442443e3acbab60c404254c333bb' # bcachefs: trans_for_each_update() now declares loop iter
    for patch in $crl_patches
        crl $patch | git am -3; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    for patch in $am_patches
        git am -3 $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
