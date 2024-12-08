#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function tmxrun -d "Wrapper for tmxrun.py"
    # The duplication is sad but it is so much better to handle adding -- in the wrapper function
    for arg in $argv
        switch $arg
            case -c -d -H --container --detach --host
                if not set -q pos_args
                    set -a py_args $arg
                else
                    set -a pos_args $arg
                end
            case '*'
                set -a pos_args $arg
        end
    end
    $PYTHON_SCRIPTS_FOLDER/tmxrun.py $py_args -- $pos_args
end
