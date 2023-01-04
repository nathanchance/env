#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_bld_krnl_for_vm -d "Wrapper for cbl_bld_krnl_for_vm.py"
    $PYTHON_SCRIPTS_FOLDER/cbl_bld_krnl_for_vm.py $argv
end
