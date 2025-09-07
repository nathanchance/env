#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function __get_distro -d "Prints a short name for the currently running distro"
    if test "$LOCATION" = mac
        echo macos
    else
        for file in /etc/os-release /usr/lib/os-release
            test -e $file; and break
        end
        set os_release_id (string match -gr '^ID="?([^"]+)"?$' </etc/os-release)
        switch "$os_release_id"
            case almalinux alpine arch debian fedora rocky ubuntu
                echo $os_release_id
            case opensuse-'*'
                echo opensuse
            case raspbian
                echo debian
            case "*"
                echo unknown
        end
    end
end
