#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function glr -d "Get latest release of software from GitHub"
    if set -q GITHUB_TOKEN
        set -a crl_args \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer $GITHUB_TOKEN"
    end
    crl $crl_args "https://api.github.com/repos/$argv[1]/releases/latest" | jq -r .tag_name
end
