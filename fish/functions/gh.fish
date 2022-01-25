#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function gh -d "Runs GitHub CLI depending on how it is available"
    if command -q gh
        command gh $argv
    else if test -x $BIN_FOLDER/gh
        $BIN_FOLDER/gh $argv
    else
        print_error "gh could not be found. Run 'upd gh' to install it."
        return 1
    end
end
