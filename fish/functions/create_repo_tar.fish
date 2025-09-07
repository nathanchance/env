#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function create_repo_tar -d "Create a tarball of a git repo from just the tracked files"
    if test (count $argv) -gt 0
        set repo $argv[1]
        if not test -d $repo
            __print_error "$repo does not exist?"
            return 1
        end
    else
        set repo (git root)
    end

    set output $repo/dist/(path basename $repo)-(date +%Y-%m-%d-%H-%M).tar.zst

    mkdir -p (path dirname $output)
    tar \
        --create \
        --directory $repo \
        --file $output \
        --zstd \
        (git -C $repo ls-files)
    echo '*' >(path dirname $output)/.gitignore

    echo "File is now available at: $output"
end
