#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function klog -d "View kernel log with bat"
    in_container_msg -h
    or return

    if contains -- --follow-new $argv
        set provides_pager true
    end
    set dmesg_cmd \
        sudo dmesg \
        --human \
        --color=always \
        $argv

    if set -q provides_pager
        $dmesg_cmd
    else
        # Ask for password first to avoid messing up bat
        sudo true
        or return

        $dmesg_cmd &| bat --style plain
    end
end
