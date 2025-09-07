#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __is_github_actions -d "Tests if running on GitHub Actions"
    set -q GITHUB_ACTIONS
end
