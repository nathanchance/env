#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function hugo_serve -d "Runs 'hugo server' based on WSL's IP address"
    if not command -q ip
        print_error "ip could not be found, please install it!"
        return 1
    end

    for arg in $argv
        switch $arg
            case -t --tailscale
                set intf tailscale
            case '*'
                set -a hugo_args $arg
        end
    end
    set -q intf
    or set intf enp

    set ip (dirname (ip addr | grep $intf | grep inet | awk '{print $2}'))
    if test -z "$ip"
        print_error "ip not found?"
        return 1
    end

    set -a hugo_args \
        --baseURL=$ip \
        --bind=0.0.0.0

    hugo server $hugo_args
end
