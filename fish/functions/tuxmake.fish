#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function tuxmake -d "Calls tuxmake from a git checkout if it is not available in PATH"
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
