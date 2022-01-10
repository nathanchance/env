#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function msh -d "Shorthand for mosh -o" -w mosh
    for arg in $argv
        switch $arg
            case -t --tailscale
                set tailscale true
            case '*'
                set msh_args $arg
        end
    end

    switch $msh_args
        case dsktp
            if test "$tailscale" = true
                set ip 100.70.49.74
            else
                set ip 192.168.4.177
            end
            set user_host nathan@$ip

        case lptp
            if test "$tailscale" = true
                set ip 100.125.217.41
            else
                set ip 192.168.4.137
            end
            set user_host nathan@$ip

        case pi3
            if test "$tailscale" = true
                set ip 100.113.197.39
            else
                set ip 192.168.4.89
            end
            set user_host pi@$ip

        case pi4
            if test "$tailscale" = true
                set ip 100.74.102.104
            else
                set ip 192.168.4.104
            end
            set user_host pi@$ip

        case svr
            set user_host nathan@$SERVER_IP

        case '*@*'
            set user_host $argv[1]

        case '*'
            print_error "Please specify a user@host combination"
            return 1
    end

    mosh $user_host
end
