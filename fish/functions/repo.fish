#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function repo -d "Runs repo depending on where it is located"
    if command -q repo
        command repo $argv
    else if test -x $BIN_FOLDER/repo
        $BIN_FOLDER/repo $argv
    else
        print_error "repo could not be found. Run 'upd repo' to install it."
        return 1
    end
end
