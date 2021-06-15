#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function is_installed -d "Checks if a package is installed depending on the package manager"
    if command -q pacman
        pacman -Q $argv &>/dev/null
    end
end
