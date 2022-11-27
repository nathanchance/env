#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function upd_nas_files -d "fish wrapper for upd_nas_files.py"
    $PYTHON_FOLDER/upd_nas_files.py $argv
end
