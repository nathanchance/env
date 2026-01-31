#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function klog -d "View kernel log with bat" -w dmesg
    __in_container_msg -h
    or return

    for arg in $argv
        set -a dmesg_args $arg
        switch $arg
            case -w --follow -W --follow-new
                set provides_pager true
        end
    end

    set dmesg_cmd \
        run0 dmesg \
        --human \
        --color=always \
        $dmesg_args

    # Ask for password first to avoid messing up bat
    request_root "dmesg access"
    or return

    if set -q provides_pager
        $dmesg_cmd
    else
        $dmesg_cmd &| bat --style plain
    end
end
