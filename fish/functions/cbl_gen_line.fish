#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_gen_line -d "Wrapper for cbl_gen_line.py"
    $PYTHON_SCRIPTS_FOLDER/cbl_gen_line.py $argv
end
