#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function __adjust_fisher_paths -d "Translate paths in _fisher_plugins to and from systemd-nspawn paths"
    if not __in_nspawn
        return
    end

    set mode $argv[1]

    # Constants
    set run_host /run/host
    set host_home /home/$USER
    set guest_home $run_host$host_home

    for idx in (seq 1 (count $_fisher_plugins))
        set val $_fisher_plugins[$idx]
        switch $mode
            case -c --container
                if string match -qr ^$host_home $val
                    set _fisher_plugins[$idx] (string replace $host_home $guest_home $val)
                end

            case -H --host
                if string match -qr ^$run_host $val
                    set _fisher_plugins[$idx] (string replace $guest_home $host_home $val)
                end
        end
    end
end
