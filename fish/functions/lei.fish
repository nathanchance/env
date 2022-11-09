#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function lei -d "Runs lei with certain folders overridden"
    set -lx XDG_CACHE_HOME $XDG_FOLDER/cache
    set -lx XDG_CONFIG_HOME $XDG_FOLDER/config
    set -lx XDG_DATA_HOME $XDG_FOLDER/share

    if command -q lei
        command lei $argv
    else
        print_error "lei could not be found!"
        return 1
    end
end
