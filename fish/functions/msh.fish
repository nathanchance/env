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
                set host aadp
            else
                set host 192.168.4.234
            end
            set user_host nathan@$host

        case amd-desktop
            if test "$tailscale" = true
                set host hp-amd-ryzen-4300g
            else
                set host 192.168.4.177
            end
            set user_host nathan@$host

        case honeycomb
            if test "$tailscale" = true
                set host honeycomb
            else
                set host 192.168.4.210
            end
            set user_host nathan@$host

        case intel-desktop
            if test "$tailscale" = true
                set host asus-intel-core-11700
            else
                set host 192.168.4.189
            end
            set user_host nathan@$host

        case intel-laptop
            if test "$tailscale" = true
                set host asus-intel-core-4210u
            else
                set host 192.168.4.137
            end
            set user_host nathan@$host

        case pi3
            if test "$tailscale" = true
                set host raspberrypi3
            else
                set host 192.168.4.199
            end
            set user_host pi@$host

        case pi4
            if test "$tailscale" = true
                set host raspberrypi4
            else
                set host 192.168.4.205
            end
            set user_host nathan@$host

        case hetzner-server
            set user_host nathan@$SERVER_IP

        case thelio
            if test "$tailscale" = true
                set host thelio-3990x
            else
                set host 192.168.4.188
            end
            set user_host nathan@$host

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
