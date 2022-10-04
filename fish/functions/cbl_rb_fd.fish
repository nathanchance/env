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
    set -a patches https://lore.kernel.org/all/20221004144145.1345772-1-nathan@kernel.org/ # fs/ntfs3: Don't use uni1 uninitialized in ntfs_d_compare()
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
