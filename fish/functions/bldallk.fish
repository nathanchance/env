#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bldallk -d "Build all kernels for ClangBuiltLinux testing"
    switch $LOCATION
        case pi
            kmake \
                -C $CBL_SRC/linux-next \
                LLVM=1 \
                LLVM_IAS=1 \
                O=.build/(uname -m) \
                distclean defconfig all; or return

            if test (uname -m) = aarch64
                kmake \
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
                lt --tree $tree
            end
            for arch in arm arm64
                $CBL_BLD/pi-scripts/build.fish $arch $CBL_BLD/rpi
            end
            $CBL_BLD/wsl2/bin/build.fish
            for krnl in linux-{next-llvm,cfi}
                upd_kernel $krnl
            end
    end
end
