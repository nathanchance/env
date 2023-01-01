#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function cbl_gen_build_report -d "fish wrapper for $PYTHON_SCRIPTS_FOLDER/cbl_gen_build_report.py"
    $PYTHON_SCRIPTS_FOLDER/cbl_gen_build_report.py $argv
end
