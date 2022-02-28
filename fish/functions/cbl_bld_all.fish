#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_bld_all -d "Build latest LLVM and test it against several Linux kernels"
    in_container_msg -c; or return

    for arg in $argv
        switch $arg
            case -n --no-stable
                set -a cbl_bld_all_krnl_args $arg
        end
    end

    # Build new LLVM and binutils
    cbl_bld_tot_tcs; or return

    # Build and boot kernels
    cbl_bld_all_krnl $cbl_bld_all_krnl_args
end
