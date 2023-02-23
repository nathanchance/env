#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function in_container -d "Checks if command is being run in a container"
    if command -q systemd-detect-virt
        set val (systemd-detect-virt -c)
        if test "$val" = lxc
            not in_orb
        else
            test "$val" != none
        end
    else
        test -n "$container"; or test -f /run/.containerenv; or test -f /.dockerenv
    end
end
