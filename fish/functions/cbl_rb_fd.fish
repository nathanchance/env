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
    set -a b4_patches https://lore.kernel.org/all/20231219201719.1967948-1-jtornosm@redhat.com/ # rpm-pkg: simplify installkernel %post
    set -a b4_patches https://lore.kernel.org/all/20231222-dma-xilinx-xdma-clang-fixes-v1-1-84a18ff184d2@kernel.org/ # dmaengine: xilinx: xdma: Fix operator precedence in xdma_prep_interleaved_dma()
    set -a b4_patches https://lore.kernel.org/all/20231222-dma-xilinx-xdma-clang-fixes-v1-2-84a18ff184d2@kernel.org/ # dmaengine: xilinx: xdma: Fix initialization location of desc in xdma_channel_isr()
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    # https://lore.kernel.org/20231221230153.GA1607352@dev-arch.thelio-3990X/
    set -a crl_patches https://lore.kernel.org/all/2229136.1703246451@warthog.procyon.org.uk/raw # Fix oops in NFS
    set -a crl_patches https://git.kernel.org/vkoul/dmaengine/p/3d0b2176e04261ab4ac095ff2a17db077fc1e46d # dmaengine: xilinx: xdma: statify xdma_prep_interleaved_dma
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
