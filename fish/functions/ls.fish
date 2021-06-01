#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ls -d "Use exa instead of ls if it is available" -w exa
    if command -q exa
        exa $argv
    else
        command ls --color=auto $argv
    end
end
