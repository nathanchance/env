#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function korg_llvm -d "Wrapper for korg_llvm.py"
    $PYTHON_SCRIPTS_FOLDER/korg_llvm.py $argv
end
