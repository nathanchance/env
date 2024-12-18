#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function b4_branch -d "Wrapper for b4_branch.py"
    $PYTHON_SCRIPTS_FOLDER/b4_branch.py $argv
end
