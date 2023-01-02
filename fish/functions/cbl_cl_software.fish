#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_cl_software -d "Clean up old versions of managed software"
    in_container_msg -c; or return

    if test (count $argv) -ne 1
        print_error "This function takes the tool whose versions will be cleaned up as an argument!"
        return 1
    end

    switch $argv[1]
        case binutils
            set folder $CBL_TC_STOW_BNTL
            set binary as
        case llvm
            set folder $CBL_TC_STOW_LLVM
            set binary clang
        case qemu
            set folder $CBL_QEMU_INSTALL
            set binary qemu-system-x86_64
    end

    set folders_to_remove (fd -d 1 -t d . $folder -x basename | sort | fzf -m --preview="$folder/{}/bin/$binary --version")
    if test -n "$folders_to_remove"
        set rm_cmd \
            rm -fr $folder/$folders_to_remove
        print_cmd $rm_cmd
        $rm_cmd
    end
end
