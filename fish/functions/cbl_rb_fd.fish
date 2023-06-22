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
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    set -a crl_patches https://git.kernel.org/kvmarm/kvmarm/p/1caa71a7a600f7781ce05ef1e84701c459653663 # KVM: arm64: Restore GICv2-on-GICv3 functionality
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
