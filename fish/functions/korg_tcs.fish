#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function korg_tcs -d "Wrapper around $USER_PYTHON_FOLDER/korg_tcs.py"
    $USER_PYTHON_FOLDER/korg_tcs.py $argv
end
