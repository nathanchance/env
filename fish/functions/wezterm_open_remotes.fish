#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function wezterm_open_remotes -d "Open a new wezterm tab for each remote machine I regularly use"
    set fish_path (command -v fish)
    set rg_path (command -v rg)
    set wezterm_path (command -v wezterm)

    # Local machines
    set hosts \
        hetzner:Hetzner \
        aadp:AADP \
        intel-desktop-11700:"Intel i7-11700" \
        amd-desktop-8745HS:"AMD mini desktop" \
        intel-laptop:"Intel laptop" \
        honeycomb:Honeycomb \
        intel-desktop-n100:"Intel mini desktop" \
        chromebox:Chromebox

    set msh_args $argv

    for item in $hosts
        set host (string split -f 1 : $item)
        set title (string split -f 2 : $item)
        $wezterm_path cli spawn -- $fish_path -c "__wezterm_title $title; msh $msh_args $host; exec $fish_path -l"
    end

    $wezterm_path cli spawn -- $fish_path -c "__wezterm_title macOS; exec $fish_path -l"
    if command -q orb; and orb list | $rg_path -q fedora
        $wezterm_path cli spawn -- $fish_path -c "__wezterm_title Fedora; ssh orb; exec $fish_path -l"
    end
end
