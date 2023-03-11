#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_test_llvm_linux -d "Test stable and mainline Linux with all supported versions of LLVM"
    in_container_msg -c; or return

    set targets $argv
    if test -z "$targets"
        set targets mainline stable
    end

    for target in $targets
        switch $target
            case mainline
                set linux_folders $CBL_BLD_C/linux
                if not test -d $linux_folders
                    mkdir -p (dirname $linux_folders)
                    git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/ $linux_folders
                end

            case stable
                set base $CBL_BLD_C/linux-stable
                cbl_upd_stbl_wrktrs $base
                set linux_folders $base-$CBL_STABLE_VERSIONS
        end

        for linux_folder in $linux_folders
            git -C $linux_folder pull --rebase

            for ver in (get_latest_stable_llvm_version $LLVM_VERSIONS_KERNEL)
                if not test -x $CBL_TC_LLVM_STORE/$ver/bin/clang-(string split -f 1 -m 1 . $ver)
                    print_error "LLVM $ver not available in $CBL_TC_LLVM_STORE!"
                    return 1
                end

                cbl_lkt \
                    --build-folder $TMP_BUILD_FOLDER/cbl_test_llvm_linux \
                    --linux-folder $linux_folder \
                    --llvm-prefix $CBL_TC_LLVM_STORE/$ver; or return
            end
        end
    end
end
