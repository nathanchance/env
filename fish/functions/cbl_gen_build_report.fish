#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_gen_build_report -d "fish wrapper for $USER_PYTHON_FOLDER/cbl_gen_build_report.py"
    $USER_PYTHON_FOLDER/cbl_gen_build_report.py $argv
end
