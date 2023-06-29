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
    set -a reverts 702bb06380f14c7e0b3c67db0a713478b826ec59 # cifs: display the endpoint IP details in DebugData
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
    set -a b4_patches https://lore.kernel.org/linux-nfs/47876afaea6c83f172bca3b1333989bbcca1aef9.1687860625.git.bcodding@redhat.com/ # NFS: Don't cleanup sysfs superblock entry if uninitialized
    set -a b4_patches https://lore.kernel.org/netdev/20230627232139.213130-1-rrameshbabu@nvidia.com/ # ptp: Make max_phase_adjustment sysfs device attribute invisible when not supported
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    set -a crl_patches https://lore.kernel.org/linux-cifs/CANT5p=rg7Q-z=9LSRjMvkBHkYk4X2t0eQCT04+myYgdGZeJP8w@mail.gmail.com/2-0001-cifs-display-the-endpoint-IP-details-in-DebugData.patch # cifs: display the endpoint IP details in DebugData
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
