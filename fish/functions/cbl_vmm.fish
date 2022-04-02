#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_vmm -d "Run cbl_vmm.py"
    $ENV_FOLDER/python/cbl_vmm.py $argv
end
