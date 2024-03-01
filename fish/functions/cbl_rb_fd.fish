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
    set -a b4_patches https://lore.kernel.org/all/20240301-pci-imx6-fix-clang-implicit-fallthrough-v1-1-db78c7cbb384@kernel.org/ # PCI: imx6: Fix clang -Wimplicit-fallthrough in imx6_pcie_probe()
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch
        or begin
            set ret $status
            git ama
            return $ret
        end
    end
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
