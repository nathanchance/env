#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function __ghostty_title -d 'Sets the title for a tab in Ghostty'
    printf "\x1b\x5d2;%s\x1b\x5c" "$argv"
end
