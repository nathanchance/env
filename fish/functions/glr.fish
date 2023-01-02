#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function glr -d "Get latest release of software from GitHub"
    crl "https://api.github.com/repos/$argv[1]/releases/latest" | jq -r .tag_name
end
