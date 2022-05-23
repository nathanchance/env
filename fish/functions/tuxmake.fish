#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function tuxmake -d "Calls tuxmake from a git checkout if it is not available in PATH"
    if string match -qr podman -- $argv
        in_container_msg -h; or return
    end

    set -lx XDG_CACHE_HOME $XDG_FOLDER/cache
    set -lx XDG_CONFIG_HOME $XDG_FOLDER/config

    if command -q tuxmake
        command tuxmake $argv
    else
        set tuxmake_run $BIN_SRC_FOLDER/tuxmake/run
        if not test -f $tuxmake_run
            upd tuxmake; or return
        end
        $tuxmake_run $argv
    end
end
