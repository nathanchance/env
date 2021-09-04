#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_test_llvm_stable_linux -d "Test all current versions of stable Linux with all supported versions of LLVM"
    cbl_bld_stbl_tcs; or return

    if not test -L $CBL_QEMU_BIN/qemu-system-x86_64
        header "Building QEMU"

        VERSION=6.0.0 cbl_bld_qemu; or return
    end

    set linux_srcs $CBL_BLD_C/linux-stable-$CBL_STABLE_VERSIONS

    for linux_src in $linux_srcs
        set branch (string replace 'stable-' '' (basename $linux_src)).y
        if not test -d $linux_src
            mkdir -p (dirname $linux_src)
            git clone -b $branch https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/ $linux_src
        end
        git -C $linux_src ch $branch
        git -C $linux_src pull --rebase
    end

    for tc_prefix in $CBL_STOW_LLVM/$CBL_LLVM_VERSIONS $CBL_USR
        for linux_src in $linux_srcs
            cbl_lkt --linux-src $linux_src --tc-prefix $tc_prefix
        end
    end
end
