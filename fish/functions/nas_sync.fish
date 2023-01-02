#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function nas_sync -d "fish wrapper for nas_sync.py"
    $PYTHON_SCRIPTS_FOLDER/nas_sync.py $argv
end
