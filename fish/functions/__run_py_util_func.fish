#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function __run_py_util_func -d "Run Python utility function from $PYTHON_LIB_FOLDER/utils.py"
    PYTHONPATH=$PYTHON_FOLDER python3 -c 'import lib.utils, sys; sys.exit(0 if lib.utils.'$argv[1]'() else 1)'
end
