#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_bld_all -d "Build latest LLVM and test it against several Linux kernels"
    switch $LOCATION
        case pi
            # Update linux-next
            cbl_clone_repo linux-next; or return
            git -C $CBL_SRC/linux-next ru; or return
            printf '\a'
            git -C $CBL_SRC/linux-next rb -i origin/master; or return

            # Build new LLVM and binutils
            cbl_bld_tot_tcs; or return

            # Build kernels
            cbl_bld_all_krnl; or return

            # Boot kernels
            kboot -a arm64 -k $CBL_SRC/linux-next/.build/aarch64
            kboot -a x86_64 -k $CBL_SRC/linux-next/.build/x86_64

        case '*'
            for arg in $argv
                switch $arg
                    case -n --no-stable
                        set -a cbl_bld_all_krnl_args $arg
                end
            end
            cbl_bld_tot_tcs; and cbl_bld_all_krnl $cbl_bld_all_krnl_args
    end
end
