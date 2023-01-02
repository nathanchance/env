#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function mvfunc -d "Move function file in $ENV_FOLDER"
    if test (count $argv) -ne 2
        print_error "mvfunc expects only two arguments!"
        return 1
    end

    set src_name $argv[1]
    set src $ENV_FOLDER/fish/functions/$src_name.fish
    if not test -f $src
        print_error "$src could not be found!"
        return 1
    end

    set dst_name $argv[2]
    set dst $ENV_FOLDER/fish/functions/$dst_name.fish
    if test -f $dst
        print_error "$dst exists, remove it manually to proceed!"
        return 1
    end

    mv -v $src $dst
    sed -i "s/$src_name/$dst_name/g" $dst
end
