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
    set -a patches https://lore.kernel.org/all/20230127162906.872395-1-trix@redhat.com/ # udf: remove reporting loc in debug output
    set -a patches https://lore.kernel.org/all/20230127221418.2522612-1-arnd@kernel.org/ # gpu: host1x: fix uninitialized variable use
    set -a patches https://lore.kernel.org/all/20230201-f2fs-fix-single-length-bitfields-v1-1-e386f7916b94@kernel.org/ # f2fs: Fix type of single bit bitfield in f2fs_io_info
    for patch in $patches
        b4 shazam -l -P _ -s $patch; or return
    end
    for hash in $ln_commits
        git -C $CBL_BLD_P/linux-next fp -1 --stdout $hash | git am; or return
    end

    # Build kernel
    cbl_bld_krnl_rpm --cfi --lto arm64; or return

    popd
end
