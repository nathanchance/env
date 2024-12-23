#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function in_dbx -d "Test if currently in a distrobox"
    # https://github.com/89luca89/distrobox/blob/3bac964bf0952674848dce170af8b41d743abe57/docs/useful_tips.md?plain=1#L40
    set -q CONTAINER_ID
end
