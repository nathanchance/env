#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function fzf -d "Call fzf with custom environment"
    set -fx TMPDIR /var/tmp/fzf
    command fzf $argv
end
