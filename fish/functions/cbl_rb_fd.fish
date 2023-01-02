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
    set -a patches https://lore.kernel.org/all/20221130070511.46558-1-vdasa@vmware.com/ # VMCI: Use threaded irqs instead of tasklets
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end
    # https://lore.kernel.org/Y6kgR4qnb23UdAEX@dev-arch.thelio-3990X/
    git rv --no-edit 1b19c4c249a196301a2a3a69aeba2c6407dad25d; or return
    # https://lore.kernel.org/Y6ki+weNcHuyH7i1@dev-arch.thelio-3990X/
    git diff 1801b065f86c^..5ec1bd594e72 | git ap -R; or return
    git ac -m 'Revert "udf: Couple more fixes for extent and directory handling"

Link: https://lore.kernel.org/Y6ki+weNcHuyH7i1@dev-arch.thelio-3990X/'

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
