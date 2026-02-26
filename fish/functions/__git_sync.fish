#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __git_sync -d "Deletes merged branches and syncs fork with upstream"
    if test (count $argv) -eq 0
        set repo (path basename $PWD)
    else
        set repo $argv[1]
    end

    if not set main_branch (git symbolic-ref refs/remotes/origin/HEAD)
        __print_error "Could not get main branch?"
        return 1
    end
    git sw (string replace 'refs/remotes/origin/' '' $main_branch); or return
    git pull; or return
    git dmb
    gh repo sync --force nathanchance/$repo
    git ru
end
