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

    cbl_upd_src_c $targets
    korg_llvm install

    if contains mainline $targets
        set -a linux_folders $CBL_SRC_C/linux
    end
    if contains stable $targets
        set -a linux_folder $CBL_SRC_C/linux-stable-$CBL_STABLE_VERSIONS
    end

    for linux_folder in $linux_folders
        for ver in $LLVM_VERSIONS_KERNEL_STABLE
            cbl_lkt \
                --build-folder (tbf cbl_test_llvm_linux) \
                --linux-folder $linux_folder \
                --llvm-prefix (korg_llvm prefix $ver); or return
        end
    end
end
