#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_bld_all_krnl -d "Build all kernels for ClangBuiltLinux testing"
    switch $LOCATION
        case pi
            podcmd kmake \
                -C $CBL_SRC/linux-next \
                LLVM=1 \
                LLVM_IAS=1 \
                O=.build/(uname -m) \
                distclean defconfig all; or return

            if test (uname -m) = aarch64
                podcmd kmake \
                    -C $CBL_SRC/linux-next \
                    ARCH=x86_64 \
                    CROSS_COMPILE=x86_64-linux-gnu- \
                    LLVM=1 \
                    LLVM_IAS=1 \
                    O=.build/x86_64 \
                    distclean defconfig all; or return
            end

        case '*'
            for arg in $argv
                switch $arg
                    case -n --no-stable
                        set no_stable true
                end
            end
            set trees linux{-next,}
            if test "$no_stable" != true
                set -a trees linux-stable-$CBL_STABLE_VERSIONS
            end
            for tree in $trees
                cbl_lkt --tree $tree
            end
            for arch in arm arm64
                podcmd $CBL_BLD/pi-scripts/build.fish $arch $CBL_BLD/rpi
            end
            podcmd $CBL_BLD/wsl2/bin/build.fish
            for krnl in linux-next-llvm
                cbl_bld_krnl_pkg $krnl
            end
    end
end
