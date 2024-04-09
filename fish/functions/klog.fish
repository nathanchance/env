#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function klog -d "View kernel log with bat"
    in_container_msg -h
    or return

    # Ask for password first to avoid messing up bat
    sudo true
    or return

    sudo dmesg --human --color=always $argv &| bat --style plain
end
