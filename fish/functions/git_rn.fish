#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function git_rn -d "Get remote name from local branch"
    if test (count $argv) -eq 0
        set branch (git bn)
    else
        set branch $argv
    end

    git for-each-ref --format='%(upstream:remotename)' refs/heads/$branch
end
