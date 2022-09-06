#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function is_github_actions -d "Tests if running on GitHub Actions"
    set -q GITHUB_ACTIONS
end
