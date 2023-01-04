#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_vmm -d "Wrapper for cbl_vmm.py"
    $PYTHON_SCRIPTS_FOLDER/cbl_vmm.py $argv
end
