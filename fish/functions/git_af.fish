#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_af -d "git add with fzf"
    set files_to_add (git status --porcelain | awk '{print $2}' | fzf -m --preview="git dh {}")
    if test -n "$files_to_add"
        git add $files_to_add
        echo "Added $files_to_add"
    end
end
