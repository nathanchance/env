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
    set -a patches https://lore.kernel.org/all/20220916110118.446132-1-michael@walle.cc/ # [PATCH] gpiolib: fix OOB access in quirk callbacks
    set -a patches https://lore.kernel.org/all/20220919160928.3905780-1-nathan@kernel.org/ # [PATCH -next] arm64/sysreg: Fix a few missed conversions
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    # https://github.com/ClangBuiltLinux/linux/issues/1712
    crl https://lore.kernel.org/all/YyigTrxhE3IRPzjs@dev-arch.thelio-3990X/raw | git ap; or return
    git ac -m "arm64: Move alternative_has_feature_{,un}likely() to their own header

Link: https://lore.kernel.org/YyigTrxhE3IRPzjs@dev-arch.thelio-3990X/"; or return

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
