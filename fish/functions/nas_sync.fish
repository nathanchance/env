#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function nas_sync -d "fish wrapper for nas_sync.py"
    $USER_PYTHON_FOLDER/nas_sync.py $argv
end
