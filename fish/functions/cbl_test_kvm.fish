#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_test_kvm -d "Test KVM against a Clang built kernel with QEMU"
    have_dev_kvm_access; or return

    switch $argv[1]
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

            set src $CBL_SRC_C/linux
            set out (tbf $src)

            cbl_upd_src c m

            if test -e $CBL_TC_LLVM/clang
                set tc_arg LLVM=1
            else
                korg_llvm install \
                    --clean-up-old-versions \
                    --versions $LLVM_VERSION_STABLE
                set tc_arg (korg_llvm var)
            end

            kmake -C $src $tc_arg O=$out distclean defconfig all
            or return

            kboot -a $arch -k $out -t 45s

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
                    set src $CBL_SRC_C/linux
                    cbl_upd_src c m

                    for toolchain in GCC LLVM
                        set out (tbf $src)/$arch/(string lower $toolchain)
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
                            if dbx_has_82a69f0
                                dbxe -- fish -c "kmake -C $src ARCH=$arch $make_args O=$out defconfig all"
                            else
                                dbxe -- "fish -c 'kmake -C $src ARCH=$arch $make_args O=$out defconfig all'"
                            end
                            or return
                        end
                        if dbx_has_82a69f0
                            dbxe -- fish -c "kboot -a $arch -k $out"
                        else
                            dbxe -- "fish -c 'kboot -a $arch -k $out'"
                        end
                        or return
                    end

                case vm
                    updfull
                    mkdir -p $TMP_FOLDER
                    cp -v /boot/vmlinuz-linux $TMP_FOLDER/bzImage
                    if dbx_has_82a69f0
                        dbxe -- fish -c "kboot -a x86_64 -k $TMP_FOLDER/bzImage -t 30s"
                    else
                        dbxe -- "fish -c 'kboot -a x86_64 -k $TMP_FOLDER/bzImage -t 30s'"
                    end
            end

        case vmm
            cbl_vmm run; or return
            if test (uname -m) = aarch64
                cbl_clone_repo boot-utils; or return
                if $CBL_GIT/boot-utils/utils/aarch64_32_bit_el1_supported
                    cbl_vmm run -a arm; or return
                end
            end
            exit
    end
end
