#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function remkdir -d "Recreate a folder"
    if test (count $argv) -ne 1
        print_error "remkdir only takes one argument!"
        return 1
    end

    rm -fr $argv
    and mkdir -p $argv
end
