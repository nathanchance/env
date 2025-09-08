#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function duf -d "Call duf with default arguments when available"
    if command -q duf
        command duf -style ascii $argv
    else
        df -hT $argv
    end
end
