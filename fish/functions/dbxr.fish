#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function dbxr -d "Remove a distrobox container"
    if test (count $argv) -eq 0
        set targets (get_dev_img_esc)
    else
        set targets $argv
    end

    dbx rm -f $targets
    rm -fr $ENV_FOLDER/.distrobox/$targets
end
