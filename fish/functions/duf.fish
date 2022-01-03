#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function duf -d "Run duf with ASCII style by default" -w duf
    if command -q duf
        command duf -style ascii $argv
    else if test -x $BIN_FOLDER/duf
        $BIN_FOLDER/duf -style ascii $argv
    else
        df -hT
    end
end
