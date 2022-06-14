#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function bat -d "Runs bat through the system or a binary in $BIN_FOLDER"
    if command -q bat
        command bat $argv
    else if test -x $BIN_FOLDER/bat
        $BIN_FOLDER/bat $argv
    else
        print_error "bat could not be found. Run 'upd bat' to install it."
        return 1
    end
end
