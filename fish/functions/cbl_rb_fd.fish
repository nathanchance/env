#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c
    or return

    set fd_src $CBL_SRC_P/fedora
    pushd $fd_src
    or return

    # Update kernel
    git ru --prune origin
    or return
    git rh origin/master

    # Patching
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert
        or return
    end
    set -a b4_patches https://lore.kernel.org/all/20240216163259.1927967-1-arnd@kernel.org/ # firmware: arm_scmi: avoid returning uninialized data
    set -a b4_patches https://lore.kernel.org/all/Zc+3PFCUvLoVlpg8@neat/ # wifi: brcmfmac: fweh: Fix boot crash on Raspberry Pi 4
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch
        or begin
            set ret $status
            git ama
            return $ret
        end
    end
    set -a crl_patches https://git.kernel.org/kvalo/ath/p/04edb5dc68f4356fd8df44c04547a729dc44f43e # wifi: ath12k: Fix uninitialized use of ret in ath12k_mac_allocate()
    for patch in $crl_patches
        crl $patch | git am -3
        or begin
            set ret $status
            git ama
            return $ret
        end
    end
    for hash in $ln_commits
        git -C $CBL_SRC_P/linux-next fp -1 --stdout $hash | git am
        or begin
            set ret $status
            git ama
            return $ret
        end
    end
    for patch in $am_patches
        git am -3 $patch
        or begin
            set ret $status
            git ama
            return $ret
        end
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64
    or return

    popd
end
