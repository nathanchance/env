#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function is_installed -d "Checks if a package is installed depending on the package manager"
    if command -q pacman
        pacman -Q $argv &>/dev/null
    else if command -q dnf
        dnf list --installed $argv &>/dev/null
    else if command -q dpkg
        dpkg -s $argv &>/dev/null
    else if command -q apk
        apk info -e $argv &>/dev/null
    else
        print_error "is_installed() does not handle this package manager"
        return 1
    end
end
