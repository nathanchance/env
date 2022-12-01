#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_report -d "Shell wrapper for cbl_report.py"
    $USER_PYTHON_FOLDER/cbl_report.py $argv
end
