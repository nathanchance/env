#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_dmb -d "Delete merged git branches"
    for branch in (git_bf)
        set remotename (git for-each-ref --format='%(upstream:remotename)' refs/heads/$branch)
        git bd $branch
        if set -q remotename
            git push $remotename :$branch; or return
        end
    end
end
