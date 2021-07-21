#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function test_kvm -d "Test KVM against a Clang built kernel with QEMU"
    set arch x86_64
    if test (uname -m) != $arch
        print_error "test_kvm only supports x86_64 at this point!"
        return 1
    end

    cbl_clone linux

    set lnx $CBL_SRC/linux
    set out build/$arch

    git -C $lnx pull -qr

    kmake -C $lnx LLVM=1 LLVM_IAS=1 O=$out distclean defconfig all; or return
    bootk -a $arch -k $lnx/$out -t 45s
end
