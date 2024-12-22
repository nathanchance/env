#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function sd_nspawn -d "Wrapper for sd_nspawn.py"
    $PYTHON_SCRIPTS_FOLDER/sd_nspawn.py $argv
end
