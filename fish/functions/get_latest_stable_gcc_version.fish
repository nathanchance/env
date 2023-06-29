#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function get_latest_stable_gcc_version -d 'Get the latest stable version for a major GCC version'
    PYTHONPATH=$PYTHON_SCRIPTS_FOLDER python3 -c 'import korg_gcc, sys

for arg in sys.argv[1:]:
    print(korg_gcc.get_latest_gcc_version(int(arg)))' $argv
end
