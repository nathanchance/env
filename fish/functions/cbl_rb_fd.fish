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
    set -a patches https://lore.kernel.org/all/20220919160928.3905780-1-nathan@kernel.org/ # [PATCH -next] arm64/sysreg: Fix a few missed conversions
    set -a patches https://lore.kernel.org/all/20220920140044.1709073-1-mark.rutland@arm.com/ # [PATCH] arm64: avoid BUILD_BUG_ON() in alternative-macros
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
