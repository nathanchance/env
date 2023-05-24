#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function remkdircd -d "Recreate a folder and cd into it"
    if test (count $argv) -ne 1
        print_error "remkdircd only takes one argument!"
        return 1
    end

    remkdir $argv
    and cd $argv
end
