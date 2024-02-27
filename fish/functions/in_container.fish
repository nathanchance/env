#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function in_container -d "Checks if command is being run in a container"
    PYTHONPATH=$PYTHON_FOLDER python3 -c 'import lib.utils, sys; sys.exit(0 if lib.utils.in_container() else 1)'
end
