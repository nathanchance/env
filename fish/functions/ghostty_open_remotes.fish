#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function ghostty_open_remotes -d "Open a new Ghostty tab for each remote machine I regularly use"
    $ENV_FOLDER/applescript/ghostty_open_remotes.scpt $argv
end
