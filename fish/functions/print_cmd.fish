#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function print_cmd -d "Wrapper for print_cmd.py"
    $PYTHON_SCRIPTS_FOLDER/print_cmd.py $argv
end
