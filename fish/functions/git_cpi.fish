#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function git_cpi -d "Interactive git cherry-pick with forgit"
    set branch (git bf)
    if test -n "$branch"
        forgit::cherry::pick $branch
    end
end
