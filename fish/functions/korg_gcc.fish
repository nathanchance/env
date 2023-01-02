#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function korg_gcc -d "Wrapper around $PYTHON_SCRIPTS_FOLDER/korg_gcc.py"
    $PYTHON_SCRIPTS_FOLDER/korg_gcc.py $argv
end
