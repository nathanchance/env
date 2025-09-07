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

    for comp_to_edit in $comps_to_edit
        if test -f $comp_to_edit
            set comp_file $comp_to_edit
        else
            set comp_file $comp_dir/$comp_to_edit.fish
            if not test -f "$comp_file"
                __print_error "$comp_file does not exist!"
                return 1
            end
        end
        set -a files_to_edit $comp_file
    end

    if test -n "$files_to_edit"
        vim -p $files_to_edit
        if test "$reload" = true
            rld
        end
    end
end
