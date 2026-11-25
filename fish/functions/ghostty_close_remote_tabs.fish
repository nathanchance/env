#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function ghostty_close_remote_tabs -d "Close remote Ghostty tabs"
    $ENV_FOLDER/applescript/ghostty_close_remote_tabs.scpt $argv
end
