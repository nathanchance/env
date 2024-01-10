#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function is_tree_dirty -d "Checks if a git tree is dirty"
    if test (count $argv) -gt 0
        set git_args -C $argv[1]
    end
    count (command git $git_args --no-optional-locks status -u --porcelain) >/dev/null
end
