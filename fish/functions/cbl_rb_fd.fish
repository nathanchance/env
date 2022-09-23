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
    set -a patches https://lore.kernel.org/all/20220922184525.3021522-1-zack@kde.org/ # kbuild: Add an option to skip vmlinux.bz2 in the rpm's
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    git diff 78ffa3e58d93bb43654788a857835bbe7afe366b^..2b109cffe6836f0bb464639cdcc59fc537e3ba41 | git ap -R; or return
    git ac -m 'thermal: Revert "Rework the trip points creation"

Link: https://lore.kernel.org/Yy4B+9yH8oT0F8nQ@zn.tnic/'

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
