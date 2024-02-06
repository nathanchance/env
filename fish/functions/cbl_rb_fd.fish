#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c; or return

    set fd_src $CBL_SRC_P/fedora
    pushd $fd_src; or return

    # Update kernel
    git ru --prune origin; or return
    git rh origin/master

    # Patching
    for revert in $reverts
        git revert --mainline 1 --no-edit $revert; or return
    end
    set -a b4_patches https://lore.kernel.org/all/20240201-topic-qdf24xx_is_back_apparently-v1-1-edb112a2ef90@linaro.org/ # Revert "tty: serial: amba-pl011: Remove QDF2xxx workarounds"
    set -a b4_patches https://lore.kernel.org/all/20240202133520.302738-1-masahiroy@kernel.org/ # kbuild: rpm-pkg: do not include depmod-generated files
    set -a b4_patches https://lore.kernel.org/all/20240202133520.302738-2-masahiroy@kernel.org/ # kbuild: rpm-pkg: mark installed files in /boot as %ghost
    set -a b4_patches https://lore.kernel.org/all/20240205-ath12k-mac-wuninitialized-v1-1-3fda7b17357f@kernel.org/ # wifi: ath12k: Fix uninitialized use of ret in ath12k_mac_allocate()
    for patch in $b4_patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for patch in $crl_patches
        crl $patch | git am -3; or return
    end
    for hash in $ln_commits
        git -C $CBL_SRC_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    for patch in $am_patches
        git am -3 $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
