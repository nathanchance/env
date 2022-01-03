#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_test_llvm_stable_linux -d "Test all current versions of stable Linux with all supported versions of LLVM"
    set base $CBL_BLD_C/linux-stable
    cbl_upd_stbl_wrktrs $base
    set linux_srcs $base-$CBL_STABLE_VERSIONS
    for linux_src in $linux_srcs
        git -C $linux_src pull --rebase
    end

    for podman_image in llvm-{11,12,13} dev
        for linux_src in $linux_srcs
            cbl_lkt --image $podman_image --linux-src $linux_src
        end
    end
end
