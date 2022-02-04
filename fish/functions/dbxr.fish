#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbxr -d "Remove a distrobox container"
    if test (count $argv) -eq 0
        set targets (get_dev_img | string replace / -)
    else
        set targets $argv
    end

    dbx rm -f $targets
end
