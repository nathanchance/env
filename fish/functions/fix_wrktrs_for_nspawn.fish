#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function fix_wrktrs_for_nspawn -d 'Fix worktree paths in gitdir files created within systemd-nspawn'
    PYTHONPATH=$PYTHON_FOLDER python3 -c 'import lib.utils, sys
from pathlib import Path

for arg in sys.argv[1:]:
    lib.utils.'(status function)'(Path(arg))' $argv
end
