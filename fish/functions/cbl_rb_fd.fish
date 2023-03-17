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
    set -a reverts ef3efc2af044f6da5bb8c55e99f2398081d99c09 # efi: libstub: Use relocated version of kernel's struct screen_info
    for revert in $reverts
        git revert --no-edit $revert; or return
    end
    set -a b4_patches https://lore.kernel.org/all/20230316132302.531724-1-trix@redhat.com/ # drm/rockchip: vop2: fix uninitialized variable possible_crtcs
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    set -a crl_patches https://git.kernel.org/efi/efi/p/5a223eba53edf2a46c1ab1e790a142241af691aa # efi: libstub: Use relocated version of kernel's struct screen_info
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
