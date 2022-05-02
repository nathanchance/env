#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbx -d "Calls distrobox based on where it is installed"
    if command -q distrobox
        command distrobox $argv
    else
        set dbx $BIN_SRC_FOLDER/distrobox/distrobox
        if not test -f $dbx
            upd distrobox; or return
        end
        $dbx $argv
    end
end
