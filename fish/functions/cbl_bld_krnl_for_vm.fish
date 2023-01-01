#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_bld_krnl_for_vm -d "Build a kernel for booting in cbl_vmm.py"
    $PYTHON_SCRIPTS_FOLDER/cbl_bld_krnl_for_vm.py $argv
end
