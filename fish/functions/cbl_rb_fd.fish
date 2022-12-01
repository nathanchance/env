#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

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
    # https://lore.kernel.org/CA+QYu4oxiRKC6hJ7F27whXy-PRBx=Tvb+-7TQTONN8qTtV3aDA@mail.gmail.com/
    git rv --no-edit dae590a6c96c799434e0ff8156ef29b88c257e60; or return

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
