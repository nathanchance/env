#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function klog -d "View kernel log with bat" -w dmesg
    in_container_msg -h
    or return

    for arg in $argv
        set -a dmesg_args $arg
        switch $arg
            case -w --follow -W --follow-new
                set provides_pager true
        end
    end

    set dmesg_cmd \
        sudo dmesg \
        --human \
        --color=always \
        $dmesg_args

    if set -q provides_pager
        $dmesg_cmd
    else
        # Ask for password first to avoid messing up bat
        sudo true
        or return

        $dmesg_cmd &| bat --style plain
    end
end
