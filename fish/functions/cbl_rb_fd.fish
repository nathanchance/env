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
    # https://lore.kernel.org/20240228043534.GG11972@google.com/
    set -a reverts 0c2f314a62342898813d5434945920f2090f44c8 # mm/zsmalloc: remove the deferred free mechanism
    set -a reverts 2258bdebb55e3ad3d30fd3849ddb955ff36825de # mm/zsmalloc: don't hold locks of all pages when free_zspage()
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert
        or return
    end
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch
        or begin
            set ret $status
            git ama
            return $ret
        end
    end
    # https://lore.kernel.org/20240222190334.GA412503@dev-arch.thelio-3990X/
    # https://lore.kernel.org/20240227192648.GA2621994@dev-arch.thelio-3990X/
    set -a crl_patches https://git.kernel.org/vfs/vfs/p/57a220844820980f8e3de1c1cd9d112e6e73da83 # pidfs: default to n for now
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
