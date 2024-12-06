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

        for func_file in $ENV_FOLDER/fish/functions/*.fish
            set func (basename $func_file | string replace .fish '')
            set desc (functions -D -v $func | tail -1)

            printf '| %-'$column_width's | %s\n' $func $desc
        end
    end &| bat $BAT_PAGER_OPTS --style plain
end
