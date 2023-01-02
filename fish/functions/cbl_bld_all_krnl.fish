#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_all_krnl -d "Build all kernels for ClangBuiltLinux testing"
    in_container_msg -c; or return

    switch $LOCATION
        case generic
            set -l lnx $CBL_SRC/linux

            cbl_clone_repo linux
            git -C $lnx urh

            cbl_lkt --linux-folder $lnx

        case honeycomb
            set -l lnx $CBL_SRC/linux

            cbl_clone_repo linux
            git -C $lnx urh

            cbl_lkt \
                --architectures arm arm64 i386 x86_64 \
                --linux-folder $lnx \
                --targets def

        case pi
            # Update linux-next
            cbl_clone_repo linux-next; or return
            git -C $CBL_SRC/linux-next urh; or return

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
                    -C $CBL_SRC/linux-next \
                    ARCH=$arch \
                    HOSTCFLAGS=-Wno-deprecated-declarations \
                    LLVM=1 \
                    O=.build/$arch \
                    distclean defconfig $image; or return
            end

            for arch in arm arm64 x86_64
                switch $arch
                    case arm
                        set kboot_arch arm32_v7
                    case '*'
                        set kboot_arch $arch
                end
                kboot -a $kboot_arch -k $CBL_SRC/linux-next/.build/$arch
            end

        case test-desktop-amd test-laptop-intel
            cbl_test_kvm build

            set lnx_src $CBL_SRC/linux
            echo CONFIG_WERROR=n >$lnx_src/allmod.config
            kmake \
                -C $lnx_src \
                KCONFIG_ALLCONFIG=1 \
                LLVM=1 \
                O=.build/(uname -m) \
                distclean allmodconfig all

        case test-desktop-intel
            set -l lnx $CBL_SRC/linux

            cbl_clone_repo linux
            git -C $lnx urh

            cbl_lkt \
                --architectures arm arm64 i386 x86_64 \
                --linux-folder $lnx

        case '*'
            for arg in $argv
                switch $arg
                    case -s --stable
                        set stable true
                end
            end
            set trees linux{-next,}
            if test "$stable" = true
                set -a trees linux-stable-$CBL_STABLE_VERSIONS
            end
            for tree in $trees
                cbl_lkt --tree $tree; or break
            end
    end
end
