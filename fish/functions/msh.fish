#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function msh -d "Shorthand for mosh -o" -w mosh
    switch $argv[1]
        case dsktp
            set user_host nathan@192.168.4.177
        case lptp
            set user_host nathan@192.168.4.137
        case pi3
            set user_host pi@192.168.4.89
        case pi4
            set user_host pi@192.168.4.104
        case svr
            set user_host nathan@$SERVER_IP
        case '*@*'
            set user_host $argv[1]
        case '*'
            print_error "Please specify a user@host combination"
            return 1
    end

    mosh -o $user_host
end
