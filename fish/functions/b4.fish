#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function b4 -d "Calls b4 from a git checkout if it is not available in PATH"
    if command -q b4
        command b4 $argv
    else
        set b4_sh $BIN_SRC_FOLDER/b4/b4.sh
        if not test -f $b4_sh
            upd b4; or return
        end
        $b4_sh $argv
    end
end
