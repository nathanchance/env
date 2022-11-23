#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function wezterm_open_remotes -d "Open a new wezterm tab for each remote machine I regularly use"
    set fish_exec (command -v fish)
    set hosts \
        thelio:Thelio \
        m3-large-x86:m3.large.x86 \
        c3-medium-x86:c3.medium.x86 \
        intel-desktop:"Intel desktop" \
        amd-desktop:"AMD desktop" \
        intel-laptop:"Intel laptop" \
        honeycomb:Honeycomb \
        pi4:"Pi 4" \
        pi3:"Pi 3"
    for item in $hosts
        set host (string split -f 1 : $item)
        set title (string split -f 2 : $item)
        wezterm cli spawn -- $fish_exec -c "wezterm_title $title; msh $host; exec $fish_exec -l"
    end
end
