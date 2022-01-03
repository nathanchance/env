#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function get_distro -d "Prints a short name for the currently running distro"
    set os_release (cat /usr/lib/os-release)
    switch "$os_release"
        case "*Arch Linux*"
            echo arch
        case "*Debian*" "*Raspbian*"
            echo debian
        case "*Ubuntu*"
            echo ubuntu
        case "*"
            echo unknown
    end
end
