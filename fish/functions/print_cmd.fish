#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function print_cmd -d "Print supplied command as if 'fish_trace' was set"
    echo '$ '($USER_PYTHON_FOLDER/print_cmd.py $argv)
end
