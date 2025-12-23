#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function wezterm_open_remotes -d "Open a new wezterm tab for each remote machine I regularly use"
    set fish_path (command -v fish)
    set rg_path (command -v rg)
    set wezterm_path (command -v wezterm)

    if test ($wezterm_path cli list | count) != 2
        __print_error "wezterm appears to have more than one tab open?"
        return 1
    end

    for arg in $argv
        switch $arg
            case -n --no-local-remotes
                set no_local_remotes true
            case -p --prepare-only
                set prepare_only true
            case '*'
                set -a msh_args $argv
        end
    end

    # Local machines
    set hosts hetzner:"🌎 Hetzner"

    if not set -q no_local_remotes
        set -a hosts \
            aadp:"🟪 AADP" \
            framework:"🟥 Framework Desktop" \
            amd-desktop-8745HS:"🟥 AMD mini desktop" \
            intel-desktop-11700:"🟦 Intel i7-11700" \
            intel-laptop:"🟦 Intel laptop" \
            honeycomb:"🟪 Honeycomb" \
            intel-desktop-n100:"🟦 Intel mini desktop" \
            chromebox:"🟦 Chromebox"
    end

    for item in $hosts
        set host (string split -f 1 : $item)
        set title (string split -f 2 : $item)

        set msh_cmd msh $msh_args $host

        set cmds "__wezterm_title $title"
        if set -q prepare_only
            set -a cmds "exec $fish_path -C 'commandline \'$msh_cmd\'' -l"
        else
            set -a cmds \
                "$msh_cmd" \
                "exec $fish_path -l"
        end

        $wezterm_path cli spawn -- $fish_path -c (string join "; " $cmds)
    end

    set mac_model (sysctl hw.model | string split -f2 ': ')
    switch $mac_model
        case Mac13,1
            set icon 🖥️
        case Mac14,2
            set icon 💻
    end
    $wezterm_path cli spawn -- $fish_path -c "__wezterm_title '$icon macOS'; exec $fish_path -l"
    if command -q orb; and orb list | $rg_path -q fedora
        $wezterm_path cli spawn -- $fish_path -c "__wezterm_title '$icon Fedora'; ssh orb; exec $fish_path -l"
    end
end
