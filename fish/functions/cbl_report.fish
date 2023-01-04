#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_report -d "Wrapper for cbl_report.py"
    $PYTHON_SCRIPTS_FOLDER/cbl_report.py $argv
end
