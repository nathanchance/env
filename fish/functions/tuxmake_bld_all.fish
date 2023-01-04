#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function tuxmake_bld_all -d "Wrapper for tuxmake_bld_all.py"
    $PYTHON_SCRIPTS_FOLDER/tuxmake_bld_all.py $argv
end
