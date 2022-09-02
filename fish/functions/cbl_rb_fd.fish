#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_rb_fd -d "Rebase generic Fedora kernel on latest linux-next"
    in_container_msg -c; or return

    set fd_src $CBL_BLD/fedora
    pushd $fd_src; or return

    # Update and patch kernel
    git ru --prune origin; or return
    git rh origin/master

    # Patching
    set -a patches https://lore.kernel.org/all/20220830101237.22782-1-gal@nvidia.com/ # [PATCH net-next] net: ieee802154: Fix compilation error when CONFIG_IEEE802154_NL802154_EXPERIMENTAL is disabled
    set -a patches https://lore.kernel.org/all/20220901195055.1932340-1-nathan@kernel.org/ # [PATCH] coresight: cti-sysfs: Mark coresight_cti_reg_store() as __maybe_unused
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
