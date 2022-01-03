#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function hyperfine -d "Runs hyperfine through the system depending on how it is available"
    if command -q hyperfine
        command hyperfine $argv
    else if test -x $BIN_FOLDER/hyperfine
        $BIN_FOLDER/hyperfine $argv
    else
        print_error "hyperfine could not be found. Run 'upd hyperfine' to install it."
        return 1
    end
end
