#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_bld_krnl_deb -d "Build a .deb kernel package"
    in_kernel_tree; or return
    cbl_gen_ubuntuconfig
    # This is purposefully inflexible with toolchain and arguments
    podcmd kmake HOSTCFLAGS=-Wno-deprecated-declarations LLVM=1 $KMAKE_DEB_ARGS O=.build/(uname -m) olddefconfig clean bindeb-pkg
end
