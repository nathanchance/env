#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function cbl_gcmt -d "Run git commit with preset commit message"
    for arg in $argv
        switch $arg
            case envk
                if not test $PWD = $ENV_FOLDER
                    __print_error "Argument ('$arg') expects to be within $ENV_FOLDER"
                    return 1
                end

                set modified_files (git diff --name-only --staged)
                if test -z "$modified_files"
                    __print_error "No files staged for modification?"
                    return 1
                end

                if string match -qr next $modified_files
                    set next true
                end
                if string match -qr mainline $modified_files
                    set mainline true
                end

                if set -q next; and set -q mainline
                    __print_error "Both -next and mainline files staged?"
                    return 1
                else if set -q next
                    set ver (string split -f 2 -m 1 - <$CBL_SRC_P/linux-next-llvm/localversion-next)
                else if set -q mainline
                    set ver (git -C $CBL_SRC_P/linux-mainline-llvm describe --abbrev=0 --tags | string replace v '')
                else
                    __print_error "Neither -next nor mainline files staged?"
                    return 1
                end

                if contains python/lib/kernel.py $modified_files
                    git c -m "env: Update for $ver"
                else if set -q mainline
                    git c -m "configs: kernel: Update linux-mainline-llvm for $ver"
                else
                    git c -m "configs: kernel: Update for $ver"
                end

            case '*'
                __print_error "Unhandled argument: $arg"
                return 1
        end
    end
end
