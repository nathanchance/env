#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function vfunc -d "View function defintion in fish with a pager"
    type $argv &| bat --color always --language fish --style plain
end
