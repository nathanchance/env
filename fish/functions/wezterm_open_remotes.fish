#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function wezterm_open_remotes -d "Open a new wezterm tab for each remote machine I regularly use"
    set fish_path (command -v fish)
    set wezterm_path (command -v wezterm)

    set hosts \
        thelio:Thelio \
        m3-large-x86:m3.large.x86 \
        c3-medium-x86:c3.medium.x86 \
        c2-medium-x86:c2.medium.x86 \
        intel-desktop:"Intel desktop" \
        amd-desktop:"AMD desktop" \
        intel-laptop:"Intel laptop" \
        honeycomb:Honeycomb \
        pi4:"Pi 4" \
        pi3:"Pi 3"
    for item in $hosts
        set host (string split -f 1 : $item)
        set title (string split -f 2 : $item)
        $wezterm_path cli spawn -- $fish_path -c "wezterm_title $title; msh $host; exec $fish_path -l"
    end

    $wezterm_path cli spawn -- $fish_path -c "wezterm_title macOS; exec $fish_path -l"
end
