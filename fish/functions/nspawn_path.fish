#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function nspawn_path -d "Translate /home paths into systemd-nspawn or host"
    set mode $argv[1]
    set path $argv[2]
    set run_host /run/host

    # The path only needs to be adjusted when it actually starts with whatever
    # the current $HOME value is, otherwise we assume that it is either already
    # in the appropriate format or it does not need to be converted.
    if string match -qr ^$HOME $path
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
                    string replace -m1 $run_host '' $path
                end
        end
    else
        echo $path
    end
end
