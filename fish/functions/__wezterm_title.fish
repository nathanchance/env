#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __wezterm_title -d "Sets the title for a tab in WezTerm"
    printf "\x1b]1337;SetUserVar=panetitle=%s\x07" "$(echo -n "$argv" | base64)"
end
