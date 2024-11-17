#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function b4_prep -d "Wrapper around 'b4 prep'"
    if test (count $argv) -ne 3
        print_error "b4_prep <repo> <branch> <b4_branch_name>"
        return 1
    end

    set repo $argv[1]
    set remote_branch $argv[2]
    set local_branch $argv[3]

    in_tree kernel; or return

    git f $repo $remote_branch
    and b4 prep -f FETCH_HEAD -n $local_branch
end
