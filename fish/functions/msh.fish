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

    if test "$tailscale" = true
        switch $target
            case aadp honeycomb
                set host $target
            case amd-desktop-8745HS
                set host beelink-amd-ryzen-8745hs
            case chromebox
                set host chromebox3
            case intel-desktop-11700
                set host asus-intel-core-11700
            case intel-desktop-n100
                set host beelink-intel-n100
            case intel-laptop
                set host msi-intel-core-10210U
            case '*'
                __print_error "Unsupported target device for Tailscale: $target"
                return 1
        end
        set user_host nathan@$host
    else
        switch $target
            case aadp amd-desktop-8745HS chromebox hetzner honeycomb intel-desktop-11700 intel-desktop-n100 intel-laptop main
                set user_host nathan@(get_ip $target)

            case '*@*'
                set user_host $target

            case '*'
                __print_error "Please specify a valid shorthand or user@host combination!"
                return 1
        end
    end

    mosh $user_host
end
