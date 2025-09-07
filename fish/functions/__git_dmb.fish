#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __git_dmb -d "Delete merged git branches"
    for branch in (__git_bf)
        set remotename (git rn $branch)
        git bd $branch
        if test -n "$remotename"
            git push $remotename :$branch; or return
        end
    end
end
