#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_sw -d "git switch with fzf"
    if test (count $argv) -gt 0
        git switch $argv
    else
        forgit::checkout::branch
    end
end
