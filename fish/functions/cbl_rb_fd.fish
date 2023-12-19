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
    git show 0df8e97085946dd79c06720678a845778b6d6bf8 scripts/package/kernel.spec | git ap -R
    git ac -m 'Partially revert "scripts: clean up IA-64 code"

To make the following patch apply cleanly'
    or return
    set -a b4_patches https://lore.kernel.org/all/20231219155659.1591792-1-jtornosm@redhat.com/ # rpm-pkg: simplify installkernel %post
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for patch in $crl_patches
        crl $patch | git am -3; or return
    end
    set -a ln_commits cce20159e877039e6cc1e8e12d1b05952c251a22 # NOTCBL: WIP: Add exports for generic out of line NUMA logging functions
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
