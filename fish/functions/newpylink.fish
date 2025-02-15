#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function newpylink -d "Generate symlink in $PYTHON_BIN_FOLDER"
    for func_name in $argv
        set script $PYTHON_SCRIPTS_FOLDER/$func_name.py
        set symlink $PYTHON_BIN_FOLDER/$func_name

        if not test -f $script
            print_error "$script does not exist?"
            return 1
        end

        if test -e $symlink; and not test -L $symlink
            print_error "$func_name already exists in $PYTHON_BIN_FOLDER!"
            return 1
        end

        ln -fnrsv $script $symlink
        or return
    end
end
