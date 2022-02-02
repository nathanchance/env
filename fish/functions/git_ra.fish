#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_ra -d "git reset all conflicting files"
    git rf (git cf)
end
