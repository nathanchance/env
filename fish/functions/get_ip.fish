#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function get_ip -d "Get a particular machine's IP address via short name or hostname"
    set device $argv[1]
    switch $device
        case aadp
            echo 10.0.1.2
        case amd-desktop-8745HS beelink-amd-ryzen-8745hs
            echo 10.0.1.8
        case chromebox chromebox3
            echo 10.0.1.14
        case framework framework-desktop framework-amd-ryzen-max-395plus
            echo 10.0.1.23
        case hetzner main
            echo $HETZNER_IP
        case honeycomb
            echo 10.0.1.17
        case intel-desktop-11700 asus-intel-core-11700
            echo 10.0.1.5
        case intel-desktop-n100 beelink-intel-n100
            echo 10.0.1.11
        case intel-laptop msi-intel-core-10210U
            echo 10.0.1.20
        case '*'
            __print_error "Unrecognized device name: $device"
            return 1
    end
end
