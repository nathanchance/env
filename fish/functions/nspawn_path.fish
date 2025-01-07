#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function nspawn_path -d "Translate /home paths into systemd-nspawn or host"
    set mode $argv[1]
    set path $argv[2]

    # Constants
    set run_host /run/host
    set host_home /home/$USER
    set guest_home $run_host$host_home

    # The path only needs to be adjusted if it starts with one of the two possible home paths
    if string match -qr '^('$host_home'|'$guest_home')' $path
        switch $mode
            # In container mode, the /home path should be prefixed with /run/host
            case -c --container
                if not string match -qr ^$run_host $path
                    set prefix $run_host
                end
                printf '%s%s\n' $prefix $path

                # In host mode, /run/host should be stripped from /home
            case -H --host
                if string match -qr ^/home $path
                    echo $path
                else
                    string replace $run_host '' $path
                end
        end
    else
        echo $path
    end
end
