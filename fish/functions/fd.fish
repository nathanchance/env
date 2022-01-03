#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function fd -d "Runs fd through the system or podman depending on how it is available"
    if command -q fd
        command fd $argv
    else if test -x $BIN_FOLDER/fd
        $BIN_FOLDER/fd $argv
    else
        print_error "fd could not be found. Run 'upd fd' to install it."
        return 1
    end
end
