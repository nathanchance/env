#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_sync -d "Deletes merged branches and syncs fork with upstream"
    git sw main; or return
    git pull; or return
    git dmb
    gh repo sync --force nathanchance/(basename $PWD)
    git ru
end
