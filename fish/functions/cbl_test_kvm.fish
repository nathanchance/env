#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_test_kvm -d "Test KVM against a Clang built kernel with QEMU"
    set arch (uname -m)
    switch $arch
        case aarch64
            set arch arm64
        case x86_64
            :
        case '*'
            print_error "cbl_test_kvm does not support $arch!"
            return 1
    end

    cbl_clone_repo linux

    set lnx $CBL_SRC/linux
    set out .build/$arch

    git -C $lnx pull -qr

    podcmd kmake -C $lnx LLVM=1 O=$out distclean defconfig all; or return
    podcmd kboot -a $arch -k $lnx/$out -t 45s
end
