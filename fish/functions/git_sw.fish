#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_sw -d "git switch with fzf"
    if test (count $argv) -gt 0
        git switch $argv
    else
        set -l branch (git_bf)
        if test -n "$branch"
            git switch $branch
        end
    end
end
