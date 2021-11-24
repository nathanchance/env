#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function diskus -d "Runs diskus through the system or podman depending on how it is available"
    if command -q diskus
        command diskus $argv
    else if test -x $BIN_FOLDER/diskus
        $BIN_FOLDER/diskus $argv
    else
        print_error "diskus could not be found. Run 'upd diskus' to install it."
        return 1
    end
end
