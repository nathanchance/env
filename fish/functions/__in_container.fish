#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __in_container -d "Checks if command is being run in a container"
    if command -q systemd-detect-virt
        set virt (systemd-detect-virt -c)
        switch $virt
            case none
                return 1
            case '*'
                if test $virt = lxc; and __in_orb
                    return 1
                end
                return 0
        end
    else
        set -q container
        or test -f /run/.containerenv
        or test -f /.dockerenv
    end
end
