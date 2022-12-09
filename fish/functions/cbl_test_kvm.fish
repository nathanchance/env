#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_test_kvm -d "Test KVM against a Clang built kernel with QEMU"
    have_dev_kvm_access; or return

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
            # It does not hurt wsl2 so just do it unconditionally.
            dbxe -- true; or return

            switch $LOCATION
                case wsl
                    set arch x86_64 # for now?
                    set src $CBL_SRC/linux
                    cbl_clone_repo (basename $src)

                    for toolchain in GCC LLVM
                        set out $src/build/$arch/(string lower $toolchain)
                        switch $arch
                            case x86_64
                                set kernel $out/arch/x86/boot/bzImage
                            case '*'
                                return 1
                        end

                        if not test -f $kernel
                            set -l make_args
                            switch $toolchain
                                case LLVM
                                    set -a make_args LLVM=1
                            end
                            dbxe -- "fish -c 'kmake -C $src ARCH=$arch $make_args O=$out defconfig all'"; or return
                        end
                        dbxe -- "fish -c 'kboot -a $arch -k $out'"; or return
                    end

                case vm
                    updfull
                    mkdir -p $TMP_FOLDER
                    cp -v /boot/vmlinuz-linux $TMP_FOLDER/bzImage
                    dbxe -- "fish -c 'kboot -a x86_64 -k $TMP_FOLDER/bzImage -t 30s'"
            end
    end
end
