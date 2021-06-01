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
                O=build/(uname -m) \
                distclean defconfig all; or return

            if test (uname -m) = aarch64
                kmake \
                    -C $CBL_SRC/linux-next \
                    ARCH=x86_64 \
                    CROSS_COMPILE=x86_64-linux-gnu- \
                    LLVM=1 \
                    LLVM_IAS=1 \
                    O=build/x86_64 \
                    distclean defconfig all; or return
            end

        case '*'
            for tree in linux-next linux linux-stable-$CBL_STABLE_VERSIONS
                lt --tree $tree
            end
            for arch in arm arm64
                $CBL_BLD/pi-scripts/build.fish $arch $CBL_BLD/rpi
            end
            $CBL_BLD/wsl2/bin/build.fish
    end
end
