#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_test_llvm_stable_linux -d "Test all current versions of stable Linux with all supported versions of LLVM"
    in_container_msg -h; or return

    set base $CBL_BLD_C/linux-stable
    cbl_upd_stbl_wrktrs $base
    set linux_folders $base-$CBL_STABLE_VERSIONS
    for linux_folder in $linux_folders
        git -C $linux_folder pull --rebase
    end

    for image in llvm-$LLVM_VERSIONS_KERNEL
        for linux_folder in $linux_folders
            dbxeph $image -- "fish -c 'cbl_lkt --linux-folder $linux_folder --system-binaries'"; or return
        end
    end
end
