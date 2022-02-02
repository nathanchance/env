#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_swf -d "git switch with fzf"
    git sw (git_bf)
end
