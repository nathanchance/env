#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_test_kvm -d "Test KVM against a Clang built kernel with QEMU"
    have_dev_kvm_access
    or return

    switch $argv[1]
        case build
            __in_container_msg -c
            or return

            set arch $UTS_MACH
            switch $arch
                case aarch64
                    set arch arm64
                case x86_64
                    :
                case '*'
                    __print_error "cbl_test_kvm does not support $arch!"
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
            __in_container_msg -h
            or return

            switch $LOCATION
                case vm
                    begin
                        updfull
                        and mkdir -p $TMP_FOLDER
                        and cp -v /boot/vmlinuz-linux $TMP_FOLDER/bzImage
                        and sd_nspawn -r 'kboot -a x86_64 -k '(nspawn_path -c $TMP_FOLDER)'/bzImage -t 30s'
                    end
                    or return
            end

        case vmm
            cbl_vmm run
            or return

            if test $UTS_MACH = aarch64
                cbl_clone_repo boot-utils
                or return

                if $CBL_GIT/boot-utils/utils/aarch64_32_bit_el1_supported
                    cbl_vmm run -a arm
                    or return
                end
            end
    end
end
