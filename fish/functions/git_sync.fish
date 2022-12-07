#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_sync -d "Deletes merged branches and syncs fork with upstream"
    if test (count $argv) -eq 0
        set repo (basename $PWD)
    else
        set repo $argv[1]
    end

    git sw main; or return
    git pull; or return
    git dmb
    gh repo sync --force nathanchance/$repo
    git ru
end
