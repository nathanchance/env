#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function fzf -d "Runs fzf depending on where it is available"
    if command -q fzf
        command fzf $argv
    else if test -x $BIN_FOLDER/fzf
        $BIN_FOLDER/fzf $argv
    else
        print_error "fzf could not be found. Run 'upd fzf' to install it."
        return 1
    end
end
