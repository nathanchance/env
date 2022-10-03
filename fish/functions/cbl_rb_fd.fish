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
    set -a patches https://lore.kernel.org/all/20221003193759.1141709-1-nathan@kernel.org/ # arm64: alternatives: Use vdso/bits.h instead of linux/bits.h
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    begin
        git rv -m1 -n 35ae225d987eda02b823073ed5eb2b70752e85d2
        and git f https://git.kernel.org/pub/scm/linux/kernel/git/mic/linux.git next
        and git cp -m1 -n 9f6e8014f86a114057acb4fc578a09e10509c474
        and git ac -m 'landlock: Diff of v6 -> v8 of "landlock: truncate support"'
    end; or return

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
