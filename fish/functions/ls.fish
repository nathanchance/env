#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function ls -d "Use exa instead of ls if it is available" -w exa
    if status is-interactive
        eza $argv
    else
        command ls $argv
    end
end
