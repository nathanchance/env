#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_test_llvm_mainline_linux -d "Test mainline Linux with all supported versions of LLVM"
    set linux_src $CBL_BLD_C/linux
    if not test -d $linux_src
        mkdir -p (dirname $linux_src)
        git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/ $linux_src
    end
    git -C $linux_src pull --rebase

    for podman_image in llvm-{11,12,13} dev/arch
        cbl_lkt --image $GHCR/$podman_image --linux-src $linux_src
    end
end
