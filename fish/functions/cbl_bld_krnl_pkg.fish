#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_bld_krnl_pkg -d "Wrapper for cbl_bld_krnl_pkg.py"
    $PYTHON_SCRIPTS_FOLDER/cbl_bld_krnl_pkg.py $argv
end
