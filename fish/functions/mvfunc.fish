#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function mvfunc -d "Move function file in $ENV_FOLDER"
    if test (count $argv) -ne 2
        print_error "mvfunc expects only two arguments!"
        return 1
    end

    set src_name $argv[1]
    set fish_src $ENV_FOLDER/fish/functions/$src_name.fish
    if not test -f $fish_src
        print_error "$fish_src could not be found!"
        return 1
    end
    set py_src $PYTHON_SCRIPTS_FOLDER/$src_name.py

    set dst_name $argv[2]
    set fish_dst $ENV_FOLDER/fish/functions/$dst_name.fish
    if test -f $fish_dst
        print_error "$fish_dst exists, remove it manually to proceed!"
        return 1
    end
    set py_dst $PYTHON_SCRIPTS_FOLDER/$dst_name.py

    mv -v $fish_src $fish_dst
    sed -i "s/$src_name/$dst_name/g" $fish_dst

    if test -f $py_src
        if test -f $py_dst
            print_error "$py_dst already exists, manually move $py_src to it if that is expected!"
            return 1
        end

        mv -v $py_src $py_dst
    end
end
