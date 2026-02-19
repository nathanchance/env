#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function tuxmake -d "Call tuxmake with custom environment"
    set -fx CONTAINERS_STORAGE_CONF $ENV_FOLDER/configs/tuxmake/storage.conf
    set -fx XDG_CACHE_HOME $XDG_FOLDER/cache
    set -fx XDG_CONFIG_HOME $XDG_FOLDER/config
    set -fx XDG_DATA_HOME $XDG_FOLDER/share
    uvx tuxmake $argv
end
