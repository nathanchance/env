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
    # https://lore.kernel.org/20240222190334.GA412503@dev-arch.thelio-3990X/
    # Does not revert cleanly, do it manually
    git revert --mainline 1 --no-edit 02cff930552c8a80633ac1a6c26a8f2f231474b2 # Merge branch 'vfs.pidfd' into vfs.all
    begin
        git rf init/main.c
        and sed -i /pidfs/d init/main.c
        and git add init/main.c
        and git commit --no-edit
    end
    or return

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
