#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbox -d "Calls distrobox from a git checkout"
    set dbox $BIN_SRC_FOLDER/distrobox/distrobox
    if not test -f $dbox
        upd distrobox; or return
    end
    $dbox $argv
end
