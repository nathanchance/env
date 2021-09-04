#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_test_llvm_mainline_linux -d "Test mainline Linux with all supported versions of LLVM"
    cbl_bld_stbl_tcs; or return

    if not test -L $CBL_QEMU_BIN/qemu-system-x86_64
        header "Building QEMU"

        VERSION=6.0.0 cbl_bld_qemu; or return
    end

    set linux_src $CBL_BLD_C/linux
    if not test -d $linux_src
        mkdir -p (dirname $linux_src)
        git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/ $linux_src
    end
    git -C $linux_src pull --rebase

    for tc_prefix in $CBL_STOW_LLVM/$CBL_LLVM_VERSIONS $CBL_USR
        cbl_lkt --linux-src $linux_src --tc-prefix $tc_prefix
    end
end
