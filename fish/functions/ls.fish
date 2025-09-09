#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function ls -d "Use eza instead of ls if it is available" -w eza
    if status is-interactive; and command -q eza
        eza $argv
    else
        command ls --color=auto $argv
    end
end
