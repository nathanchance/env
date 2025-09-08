#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function b4 -d "Call b4 with custom environment"
    set -fx XDG_CACHE_HOME $XDG_FOLDER/cache
    set -fx XDG_CONFIG_HOME $XDG_FOLDER/config
    set -fx XDG_DATA_HOME $XDG_FOLDER/share
    command b4 $argv
end
