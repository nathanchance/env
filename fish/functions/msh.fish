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
            # Equinix server, perform look up
            if string match -qr "[a|c|g|m|n|s|t|x]{1}[1-3]{1}-.*" $msh_args
                set equinix_ips $HOME/.equinix_ips
                if test -f $equinix_ips
                    set ip (grep $msh_args $equinix_ips | string split -f 2 ,)
                    if test -z "$ip"
                        print_error "Could not find $msh_args in $equinix_ips!"
                        return 1
                    end
                    set user_host nathan@$ip
                else
                    print_error "Equinix hostname provided but no IP file!"
                    return 1
                end
            else
                print_error "Please specify a valid shorthand or user@host combination!"
                return 1
            end
    end

    mosh $user_host
end
