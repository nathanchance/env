#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_all_krnl -d "Build all kernels for ClangBuiltLinux testing"
    in_container_msg -c; or return

    switch $LOCATION
        case aadp generic
            cbl_upd_src c m

            cbl_lkt --linux-folder $CBL_SRC_C/linux

        case chromebox
            cbl_test_kvm build
            or return

        case honeycomb
            cbl_upd_src c m

            cbl_lkt \
                --architectures arm arm64 i386 x86_64 \
                --linux-folder $CBL_SRC_C/linux \
                --targets def

        case pi
            cbl_upd_src c n

            for arch in arm arm64 x86_64
                switch $arch
                    case arm
                        set image zImage
                    case arm64
                        set image Image.gz
                    case x86_64
                        set image bzImage
                end

                kmake \
                    -C $CBL_SRC_C/linux-next \
                    ARCH=$arch \
                    HOSTCFLAGS=-Wno-deprecated-declarations \
                    LLVM=1 \
                    O=(tbf linux-next)/$arch \
                    distclean defconfig $image
                or return
            end

            for arch in arm arm64 x86_64
                kboot -a $arch -k (tbf linux-next)/$arch
                or return
            end

        case test-desktop-amd-8745HS test-desktop-intel-n100 test-laptop-intel
            cbl_test_kvm build
            or return

            if test -e $CBL_TC_LLVM/clang
                set tc_arg LLVM=1
            else
                set tc_arg (korg_llvm var)
            end

            kmake \
                -C $CBL_SRC_C/linux \
                KCONFIG_ALLCONFIG=(echo CONFIG_WERROR=n | psub) \
                $tc_arg \
                O=(tbf linux) \
                distclean allmodconfig all

        case test-desktop-intel-11700
            cbl_upd_src c m

            cbl_lkt \
                --architectures arm arm64 i386 x86_64 \
                --linux-folder $CBL_SRC_C/linux

        case '*'
            for arg in $argv
                switch $arg
                    case -l --lts
                        set lts true
                    case -s --short
                        set short true
                end
            end
            set trees linux-next linux
            if not test "$short" = true
                set -a trees linux-stable-$CBL_STABLE_VERSIONS[1]
            end
            if test "$lts" = true
                set -a trees linux-stable-$CBL_STABLE_VERSIONS[2..-1]
            end
            for tree in $trees
                cbl_lkt --tree $tree; or break
            end
    end
end
