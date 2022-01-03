#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function arc -d "Calls arcanist from a git checkout"
    set arc $BIN_SRC_FOLDER/arcanist/arcanist/bin/arc
    if not test -x $arc
        upd arc
    end
    $arc $argv
end
