#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function lsfuncs -d "List function names and descriptions from $ENV_FOLDER/fish/functions"
    begin
        set column_width 30

        set border (string repeat -n $column_width -N -)

        printf '| %s | %s |\n' $border $border
        printf '| %-'$column_width's | %-'$column_width's |\n' Function Description
        printf '| %s | %s |\n' $border $border

        for func in (get_my_funcs)
            if test -e $PYTHON_BIN_FOLDER/$func
                set desc ($func -h | string match -er '^[A-Z].*$')
            else
                set desc (functions -D -v $func | tail -1)
            end
            printf '| %-'$column_width's | %s\n' $func $desc
        end
    end &| bat $BAT_PAGER_OPTS --style plain
end
