#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function korg_gcc -d "Wrapper around $USER_PYTHON_FOLDER/korg_gcc.py"
    $USER_PYTHON_FOLDER/korg_gcc.py $argv
end
