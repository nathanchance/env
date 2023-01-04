#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function gen_patch_cc -d "Wrapper for gen_patch_gcc.py"
    $PYTHON_SCRIPTS_FOLDER/gen_patch_cc.py $argv
end
