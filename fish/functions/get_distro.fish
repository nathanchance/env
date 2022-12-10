#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function get_distro -d "Prints a short name for the currently running distro"
    if test "$LOCATION" = mac
        echo macos
    else
        for file in /etc/os-release /usr/lib/os-release
            test -e $file; and break
        end
        set os_release_id (grep ^ID= $file | string split -f 2 = | string replace -a '"' "")
        switch "$os_release_id"
            case alpine arch debian fedora ubuntu
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
