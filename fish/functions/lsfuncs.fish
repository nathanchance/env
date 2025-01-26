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
            printf '| %-'$column_width's | %s\n' $func (functions -D -v $func | tail -1)
        end
    end &| bat $BAT_PAGER_OPTS --style plain
end
