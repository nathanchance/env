#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_sw -d "git switch with fzf"
    if test (count $argv) -gt 0
        set ref $argv
    else
        set ref (git bf)
    end
    if test -n "$ref"
        git switch $ref
    end
end
