#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function mvfunc -d "Move function file in $ENV_FOLDER"
    if test (count $argv) -ne 2
        print_error "mvfunc expects only two arguments!"
        return 1
    end

    set src $ENV_FOLDER/fish/functions/$argv[1].fish
    if not test -f $src
        print_error "$src could not be found!"
        return 1
    end

    set dst $ENV_FOLDER/fish/functions/$argv[2].fish
    if test -f $dst
        print_error "$dst exists, remove it manually to proceed!"
        return 1
    end

    mv -v $src $dst
end
