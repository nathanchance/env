#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_test_llvm_linux -d "Test stable and mainline Linux with all supported versions of LLVM"
    in_container_msg -c; or return

    if not test -f $HOME/.muttrc.notifier
        print_error "This function runs cbl_lkt, which requires the notifier!"
        return 1
    end

    set targets $argv
    if test -z "$targets"
        set targets mainline stable
    end

    cbl_upd_lnx_c $targets

    if contains mainline $targets
        set -a linux_folders $CBL_BLD_C/linux
    end
    if contains stable $targets
        set -a linux_folder $CBL_BLD_C/linux-stable-$CBL_STABLE_VERSIONS
    end

    for linux_folder in $linux_folders
        for ver in (korg_llvm latest $LLVM_VERSIONS_KERNEL_STABLE)
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
