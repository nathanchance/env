#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function vwfunc -d "View function defintion in fish with a pager"
    set func_file $PYTHON_SCRIPTS_FOLDER/$argv.py
    if test -f "$func_file"
        vw -c $func_file
    else
        type $argv &| bat \
            --color always \
            --language fish \
            $BAT_PAGER_OPTS \
            --style plain
    end
end
