#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function is_shallow_clone -d "Tests if the supplied git repository is shallow"
    set repo $argv[1]
    if not test -d $repo
        print_error "Repository ('$repo') cannot be found!"
        return 1
    end
    set git_dir (git -C $repo rev-parse --absolute-git-dir)
    test -e $git_dir/shallow
end
