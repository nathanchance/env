#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_cl_software -d "Clean up old versions of managed software"
    in_container_msg -c; or return

    for arg in $argv
        switch $arg
            case binutils
                set folder $CBL_TC_BNTL_STORE
                set binary as
            case gcc
                set folder $CBL_TC_GCC_STORE
                set binary aarch64-linux-gcc
            case llvm
                set folder $CBL_TC_LLVM_STORE
                set binary clang
            case qemu
                set folder $CBL_QEMU_INSTALL
                set binary qemu-system-x86_64
        end

        set folders_to_remove (path filter -d $folder/* | path basename | path sort | run_cmd fzf -m --preview="$folder/{}/bin/$binary --version")
        if test -n "$folders_to_remove"
            set rm_cmd \
                sudo rm -fr $folder/$folders_to_remove
            print_cmd $rm_cmd
            $rm_cmd
        end
    end
end
