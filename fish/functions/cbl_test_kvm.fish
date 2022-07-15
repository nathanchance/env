#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_test_kvm -d "Test KVM against a Clang built kernel with QEMU"
    switch $argv
        case build
            in_container_msg -c; or return

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

            kmake -C $lnx LLVM=1 O=$out distclean defconfig all; or return
            kboot -a $arch -k $lnx/$out -t 45s

        case nested
            in_container_msg -h; or return

            # Start container before updating, as podman requires some kernel modules,
            # which need to be loaded before updating, as an update to linux will
            # remove the modules on disk for the current running kernel version.
            dbxe -- true; or return

            updfull
            mkdir -p $TMP_FOLDER
            cp -v /boot/vmlinuz-linux $TMP_FOLDER/bzImage
            dbxe -- "fish -c 'kboot -a x86_64 -k $TMP_FOLDER/bzImage -t 30s'"
    end
end
