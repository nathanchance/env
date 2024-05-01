#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function wezterm_open_remotes -d "Open a new wezterm tab for each remote machine I regularly use"
    set fish_path (command -v fish)
    set rg_path (command -v rg)
    set wezterm_path (command -v wezterm)

    # Local machines
    set hosts \
        thelio:Thelio \
        aadp:AADP \
        intel-desktop-11700:"Intel full desktop" \
        amd-desktop:"AMD desktop" \
        intel-desktop-n100:"Intel mini desktop" \
        intel-laptop:"Intel laptop" \
        honeycomb:Honeycomb \
        pi4:"Pi 4" \
        pi3:"Pi 3"

    set msh_args $argv

    # Remote machines
    set equinix_ips $ICLOUD_DOCS_FOLDER/.equinix_ips
    if test -f $equinix_ips
        for line in (cat $equinix_ips)
            set host (string split -f 1 , $line)
            set title (string replace -a - . $host)

            set -a hosts $host:$title
        end
    end

    for item in $hosts
        set host (string split -f 1 : $item)
        set title (string split -f 2 : $item)
        $wezterm_path cli spawn -- $fish_path -c "wezterm_title $title; msh $msh_args $host; exec $fish_path -l"
    end

    $wezterm_path cli spawn -- $fish_path -c "wezterm_title macOS; exec $fish_path -l"
    if command -q orb; and orb list | $rg_path -q fedora
        $wezterm_path cli spawn -- $fish_path -c "wezterm_title Fedora; ssh orb; exec $fish_path -l"
    end
end
