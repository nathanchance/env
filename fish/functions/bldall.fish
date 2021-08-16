#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bldall -d "Build latest LLVM and test it against several Linux kernels"
    switch $LOCATION
        case pi
            # Update linux-next
            cbl_clone linux-next; or return
            git -C $CBL_SRC/linux-next ru; or return
            printf '\a'
            git -C $CBL_SRC/linux-next rb -i origin/master; or return

            # Build new LLVM and binutils
            bldtcs; or return

            # Build kernels
            bldallk; or return

            # Boot kernels
            bootk -a arm64 -k $CBL_SRC/linux-next/.build/aarch64
            bootk -a x86_64 -k $CBL_SRC/linux-next/.build/x86_64

        case '*'
            bldtcs; and bldallk
    end
end
