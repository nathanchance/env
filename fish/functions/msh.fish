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
                set host (get_ip $msh_args)
            end
            set user_host nathan@$host

        case amd-desktop-8745HS
            if test "$tailscale" = true
                set host beelink-amd-ryzen-8745hs
            else
                set host (get_ip $msh_args)
            end
            set user_host nathan@$host

        case chromebox
            if test "$tailscale" = true
                set host chromebox3
            else
                set host (get_ip $msh_args)
            end
            set user_host nathan@$host

        case hetzner main
            set user_host nathan@$HETZNER_IP

        case honeycomb
            if test "$tailscale" = true
                set host honeycomb
            else
                set host (get_ip $msh_args)
            end
            set user_host nathan@$host

        case intel-desktop-11700
            if test "$tailscale" = true
                set host asus-intel-core-11700
            else
                set host (get_ip $msh_args)
            end
            set user_host nathan@$host

        case intel-desktop-n100
            if test "$tailscale" = true
                set host beelink-intel-n100
            else
                set host (get_ip $msh_args)
            end
            set user_host nathan@$host

        case intel-laptop
            if test "$tailscale" = true
                set host msi-intel-core-10210U
            else
                set host (get_ip $msh_args)
            end
            set user_host nathan@$host

            # case thelio
            #     if test "$tailscale" = true
            #         set host thelio-3990x
            #     else
            #         set host
            #     end
            #     set user_host nathan@$host

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
