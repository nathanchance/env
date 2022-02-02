#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function edfunc -d "Edit function file in $ENV_FOLDER"
    for arg in $argv
        switch $arg
            case -r --reload
                set reload true
            case '*'
                set -a funcs_to_edit $arg
        end
    end

    for func_to_edit in $funcs_to_edit
        if test -f $func_to_edit
            set func_file $func_to_edit
        else
            set func_file $ENV_FOLDER/fish/functions/$func_to_edit.fish
            if not test -f "$func_file"
                print_error "$func_file does not exist!"
                return 1
            end
        end
        vim $func_file
    end

    if test "$reload" = true
        rld
    end
end
