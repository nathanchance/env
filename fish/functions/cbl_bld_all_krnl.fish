#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_all_krnl -d "Build all kernels for ClangBuiltLinux testing"
    in_container_msg -c; or return

    switch $LOCATION
        case aadp generic
            cbl_upd_lnx_c m

            cbl_lkt --linux-folder $CBL_BLD_C/linux

        case honeycomb
            cbl_upd_lnx_c m

            cbl_lkt \
                --architectures arm arm64 i386 x86_64 \
                --linux-folder $CBL_BLD_C/linux \
                --targets def

        case pi
            cbl_upd_lnx_c n

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
                    -C $CBL_BLD_C/linux-next \
                    ARCH=$arch \
                    HOSTCFLAGS=-Wno-deprecated-declarations \
                    LLVM=1 \
                    O=(kbf linux-next)/$arch \
                    distclean defconfig $image
                or return
            end

            for arch in arm arm64 x86_64
                kboot -a $arch -k (kbf linux-next)/$arch
                or return
            end

        case test-desktop-amd test-laptop-intel
            cbl_test_kvm build

            kmake \
                -C $CBL_BLD_C/linux \
                KCONFIG_ALLCONFIG=(echo CONFIG_WERROR=n | psub) \
                LLVM=1 \
                O=(kbf linux)/(uname -m) \
                distclean allmodconfig all

        case test-desktop-intel
            cbl_upd_lnx_c m

            cbl_lkt \
                --architectures arm arm64 i386 x86_64 \
                --linux-folder $CBL_BLD_C/linux

        case '*'
            for arg in $argv
                switch $arg
                    case -l --lts
                        set lts true
                end
            end
            set trees linux{-next,,-stable-$CBL_STABLE_VERSIONS[1]}
            if test "$lts" = true
                set -a trees linux-stable-$CBL_STABLE_VERSIONS[2..-1]
            end
            for tree in $trees
                cbl_lkt --tree $tree; or break
            end
    end
end
