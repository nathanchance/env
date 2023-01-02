#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function wally_flash -d "Flash keyboard firmware file"
    if test (count $argv) -gt 0
        set file $argv[1]
    else
        set file (fd -e bin . $HOME/Downloads | fzf)
        test -z "$file"; and return 0
    end

    set file (realpath $file)
    wally-cli $file; or return
    rm -v $file
end
