#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function clone_lnx_repo -d "Clones a linux repo"
    if test (count $argv) -ne 2
        print_error "$(status function) <repo> <dest>"
        return 1
    end

    set repo $argv[1]
    switch $repo
        case linux
            set user_repo torvalds/linux
        case linux-next
            set user_repo next/linux-next
        case linux-stable
            set user_repo stable/linux
        case '*'
            print_error "Unsupported repo ('$repo') provided!"
            return 1
    end
    set bundle $NAS_FOLDER/bundles/$repo.bundle
    set url https://git.kernel.org/pub/scm/linux/kernel/git/$user_repo.git/

    set dest $argv[2]
    if test -e $dest
        print_warning "Destination ('$dest') already exists, skipping..."
        return 0
    end

    mkdir -p (dirname $dest)

    if test -e $bundle
        clone_from_bundle $bundle $dest $url master
    else
        git clone $url $dest
    end
end
