#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function git -d "Call hub as git if it is installed" -w hub
    if command -q hub
        hub $argv
    else
        command git $argv
    end
end
