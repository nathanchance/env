#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function create_repo_tar -d "Create a tarball of a git repo from just the tracked files"
    if test (count $argv) -gt 0
        set repo $argv[1]
        if not test -d $repo
            print_error "$repo does not exist?"
            return 1
        end
    else
        set repo (git root)
    end

    set output $repo/dist/(basename $repo)-(date +%Y-%m-%d-%H-%M).tar.zst

    mkdir -p (dirname $output)
    tar \
        --create \
        --directory $repo \
        --file $output \
        --zstd \
        (git -C $repo ls-files)
    echo '*' >(dirname $output)/.gitignore

    echo "File is now available at: $output"
end
