#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function msh -d "Shorthand for mosh -o" -w mosh
    for arg in $argv
        switch $arg
            case -t --tailscale
                set tailscale true
            case '*'
                set target $arg
        end
    end

    switch $target
        case aadp
            set title "🟪 AADP"
        case amd-desktop-8745HS
            set title "🟥 AMD mini desktop"
        case chromebox
            set title "🟦 Chromebox"
        case framework-desktop
            set title "🟥 Framework Desktop"
        case hetzner
            set title "🌎 Hetzner"
        case honeycomb
            set title "🟪 Honeycomb"
        case intel-desktop-11700
            set title "🟦 Intel i7-11700"
        case intel-desktop-n100
            set title "🟦 Intel mini desktop"
        case intel-laptop
            set title "🟦 Intel laptop"
        case mac-studio
            set title "🟪 Mac Studio"
        case orb
            set mac_model (sysctl hw.model | string split -f2 ': ')
            switch $mac_model
                case Mac13,1 Mac16,9
                    set icon 🖥️
                case Mac1{4,7},2
                    set icon 💻
            end
            set title "$icon Fedora"
    end

    if test "$tailscale" = true
        switch $target
            case aadp honeycomb
                set host $target
            case amd-desktop-8745HS
                set host beelink-amd-ryzen-8745hs
            case chromebox
                set host chromebox3
            case framework-desktop
                set host framework-amd-ryzen-maxplus-395
            case intel-desktop-11700
                set host asus-intel-core-11700
            case intel-desktop-n100
                set host beelink-intel-n100
            case intel-laptop
                set host msi-intel-core-10210U
            case mac-studio
                set host mac-studio-m1-max
            case '*'
                __print_error "Unsupported target device for Tailscale: $target"
                return 1
        end
        set possible_user_host nathan@$host
    else
        switch $target
            case aadp amd-desktop-8745HS chromebox framework-desktop hetzner honeycomb intel-desktop-11700 intel-desktop-n100 intel-laptop mac-studio main
                set possible_user_host nathan@(get_ip $target)

            case orb
                if not set -q remote_cmd
                    set remote_cmd ssh
                end
                set possible_user_host orb

            case '*@*'
                set possible_user_host $target

            case '*'
                __print_error "Please specify a valid shorthand or user@host combination!"
                return 1
        end
    end
    if not set -q remote_cmd
        set remote_cmd mosh
    end
    if not set -q user_host
        set user_host $possible_user_host
    end

    if set -q title
        __ghostty_title $title
    end
    $remote_cmd $user_host
    if set -q title
        __ghostty_title
    end
end
