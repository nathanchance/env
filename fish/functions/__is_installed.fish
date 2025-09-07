#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function __is_installed -d "Checks if a package is installed depending on the package manager"
    if command -q pacman
        pacman -Q $argv &>/dev/null
    else if command -q dnf
        dnf list --installed $argv &>/dev/null
    else if command -q dpkg
        dpkg -s $argv &>/dev/null
    else if command -q apk
        apk info -e $argv &>/dev/null
    else
        __print_error "__is_installed() does not handle this package manager"
        return 1
    end
end
