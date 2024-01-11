#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function edfunc -d "Edit function or script file in $ENV_FOLDER"
    for arg in $argv
        switch $arg
            case -f --fzf
                set fzf true
            case -r --reload
                set reload true
            case '*'
                set -a funcs_to_edit $arg
        end
    end

    if test "$fzf" = true
        set func_dir $ENV_FOLDER/fish/functions
        set -a funcs_to_edit (fd . $func_dir | sed -e "s;$func_dir/;;g" -e "s;.fish;;" | fzf -m)
    end

    for func_to_edit in $funcs_to_edit
        if test -f $func_to_edit
            set func_file $func_to_edit
        else
            set func_file $PYTHON_SCRIPTS_FOLDER/$func_to_edit.py
            if not test -f "$func_file"
                set func_file $ENV_FOLDER/fish/functions/$func_to_edit.fish
            end
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
