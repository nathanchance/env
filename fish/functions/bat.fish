#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bat -d "Runs bat through the system or podman depending on how it is available"
    if command -q bat
        command bat $argv
    else if test -x $BIN_FOLDER/bat
        $BIN_FOLDER/bat $argv
    else
        print_error "bat could not be found. Run 'upd bat' to install it."
        return 1
    end
end
