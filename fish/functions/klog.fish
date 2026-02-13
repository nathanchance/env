#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function klog -d "View kernel log with bat" -w dmesg
    __in_container_msg -h
    or return

    for arg in $argv
        switch $arg
            case --filter
                set filter true
            case --no-bat
                set no_bat true
            case --skip-root
                set skip_root true
            case -w --follow -W --follow-new
                set provides_pager true
                set -a dmesg_args $arg
            case '*'
                set -a dmesg_args $arg
        end
    end

    set dmesg_cmd \
        run0 dmesg \
        --human \
        --color=always \
        $dmesg_args
    set bat_cmd \
        bat \
        --style plain

    # Ask for password first to avoid messing up bat
    if not set -q skip_root
        request_root "dmesg access"
        or return
    end

    if set -q filter
        if set -q no_bat
            $dmesg_cmd &| filter_dmesg
        else
            $dmesg_cmd &| filter_dmesg &| $bat_cmd
        end
    else if set -q provides_pager; or set -q no_bat
        $dmesg_cmd
    else
        $dmesg_cmd &| $bat_cmd
    end
end
