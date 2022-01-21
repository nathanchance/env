#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbx -d "Calls distrobox from a git checkout"
    set dbx $BIN_SRC_FOLDER/distrobox/distrobox
    if not test -f $dbx
        upd distrobox; or return
    end
    $dbx $argv
end
