#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function gen_llvm_line -d "Wrapper for gen_llvm_line.py"
    $PYTHON_SCRIPTS_FOLDER/gen_llvm_line.py $argv
end
