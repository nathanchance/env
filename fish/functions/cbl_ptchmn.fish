#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_ptchmn -d "Wrapper for cbl_ptchmn.py"
    $PYTHON_SCRIPTS_FOLDER/cbl_ptchmn.py $argv
end
