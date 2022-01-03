#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function rg -d "Runs ripgrep through the system or podman depending on how it is available"
    if command -q rg
        command rg $argv
    else if test -x $BIN_FOLDER/rg
        $BIN_FOLDER/rg $argv
    else
        print_error "rg could not be found. Run 'upd rg' to install it or install the 'ripgrep' package."
        return 1
    end
end
