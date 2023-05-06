#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function cbl_lkt_for_all_llvm -d "Run cbl_lkt for all supported LLVM versions"
    for idx in (seq 1 (count $LLVM_VERSIONS_KERNEL))
        set -l cbl_lkt_args $argv
        if test $idx -ne 1
            set -a cbl_lkt_args \
                --llvm-prefix $CBL_TC_LLVM_STORE/(get_latest_stable_llvm_version $LLVM_VERSIONS_KERNEL[$idx])
        end
        cbl_lkt $cbl_lkt_args; or return
    end
end
