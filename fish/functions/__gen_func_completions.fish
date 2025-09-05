#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function __gen_func_completions -d "Generate completions for self-created functions"
    get_my_funcs | string match -er (commandline -ct) | while read -l func
        if test -e $PYTHON_BIN_FOLDER/$func
            set desc ($func -h | string match -er '^[A-Z].*$')
        else
            set desc (functions -D -v $func | tail -1)
        end
        echo $func\t$desc
    end
end
