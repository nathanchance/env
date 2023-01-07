#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

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
        case aadp
            if test "$tailscale" = true
                set ip 100.124.99.17
            else
                set ip 192.168.4.234
            end
            set user_host nathan@$ip

        case amd-desktop
            if test "$tailscale" = true
                set ip 100.76.142.56
            else
                set ip 192.168.4.177
            end
            set user_host nathan@$ip

        case honeycomb
            if test "$tailscale" = true
                set ip 100.88.75.80
            else
                set ip 192.168.4.210
            end
            set user_host nathan@$ip

        case intel-desktop
            if test "$tailscale" = true
                set ip 100.98.119.115
            else
                set ip 192.168.4.189
            end
            set user_host nathan@$ip

        case intel-laptop
            if test "$tailscale" = true
                set ip 100.71.203.25
            else
                set ip 192.168.4.137
            end
            set user_host nathan@$ip

        case pi3
            if test "$tailscale" = true
                set ip 100.125.231.2
            else
                set ip 192.168.4.199
            end
            set user_host pi@$ip

        case pi4
            if test "$tailscale" = true
                set ip 100.77.101.110
            else
                set ip 192.168.4.205
            end
            set user_host pi@$ip

        case hetzner-server
            set user_host nathan@$SERVER_IP

        case thelio
            if test "$tailscale" = true
                set ip 100.108.36.65
            else
                set ip 192.168.4.188
            end
            set user_host nathan@$ip

        case '*@*'
            set user_host $argv[1]

        case '*'
            # Equinix server, perform look up
            if string match -qr "[a|c|f|g|m|n|s|t|x]{1}[1-3]{1}-.*" $msh_args
                switch $LOCATION
                    case mac
                        set equinix_ips $ICLOUD_DOCS_FOLDER/.equinix_ips
                    case '*'
                        set equinix_ips $HOME/.equinix_ips
                end
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
