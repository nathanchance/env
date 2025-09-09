#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function edcomp -d "Edit completions in $ENV_FOLDER"
    for arg in $argv
        switch $arg
            case -f --fzf
                set fzf true
            case -r --reload
                set reload true
            case '*'
                set -a comps_to_edit $arg
        end
    end

    set comp_dir $ENV_FOLDER/fish/completions
    if test "$fzf" = true
        set -a comps_to_edit (path filter -f $comp_dir/* | path basename | path change-extension '' | fzf -m --preview "cat $comp_dir/{}.fish")
    end

    set files_to_edit $comp_dir/$comps_to_edit.fish
    if test -n "$files_to_edit"
        vim -p $files_to_edit
        if test "$reload" = true
            rld
        end
    end
end
