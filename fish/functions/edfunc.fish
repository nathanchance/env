#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function edfunc -d "Edit function file in $ENV_FOLDER"
    for func_name in $argv
        set func_file $ENV_FOLDER/fish/functions/$func_name.fish
        if test -f "$func_file"
            vim $func_file
        else
            print_error "$func_file does not exist!"
        end
    end
end
