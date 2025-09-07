#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function __clone_repo_from_bundle -d "Clone repo using a clone bundle if possible"
    set num_args (count $argv)
    if test $num_args -lt 2; or test $num_args -gt 3
        __print_error "$(status function) <repo> <dest> (<existing_bundle>)"
        return 1
    end

    set repo $argv[1]
    switch $repo
        case binutils
            set url https://sourceware.org/git/binutils-gdb.git
        case linux
            set user_repo torvalds/linux
        case linux-next
            set user_repo next/linux-next
        case linux-stable
            set user_repo stable/linux
        case llvm-project
            set branch main
            set url https://github.com/llvm/llvm-project.git
        case '*'
            __print_error "Unsupported repo ('$repo') provided!"
            return 1
    end

    set dest $argv[2]
    if test -e $dest
        __print_warning "Destination ('$dest') already exists, skipping..."
        return 0
    end

    set nas_bundle $NAS_FOLDER/bundles/$repo.bundle
    if test -e $nas_bundle
        set bundle $nas_bundle
    end
    if not set -q bundle
        if test $num_args -eq 3
            set bundle $argv[3]
            if not test -e $bundle
                __print_warning "Provided bundle ('$bundle') does not existing, cloning via $url..."
                set -e bundle
            end
        end
    end

    if not set -q url
        set url https://git.kernel.org/pub/scm/linux/kernel/git/$user_repo.git/
    end

    if not set -q branch
        set branch master
    end

    mkdir -p (path dirname $dest)

    if set -q bundle
        git clone $bundle $dest
        and git -C $dest remote remove origin
        and git -C $dest remote add origin $url
        and git -C $dest remote update --prune origin
        and git -C $dest checkout $branch
        and git -C $dest branch --set-upstream-to origin/$branch
        and git -C $dest reset --hard origin/$branch
    else
        git clone $url $dest
    end
end
