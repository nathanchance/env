#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function has_detached_head -d "Returns true if supplied git repo in detached HEAD state"
    test -z "$(git -C $argv branch --show-current)"
end
