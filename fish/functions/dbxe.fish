#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbxe -d "Shorthand for 'distrobox enter'"
    in_container_msg -h; or return

    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case -e --env
                set next (math $i + 1)
                set -a add_args $arg $argv[$next]
                set i $next
            case --env='*'
                set -a add_args $arg
            case '*'
                set dbx_img $arg
        end
        set i (math $i + 1)
    end

    if not set -q dbx_img
        set dbx_img (string replace / - (get_dev_img))
    end

    if test (count $add_args) -gt 0
        set dbx_args -a "$add_args"
    end

    dbx enter $dbx_args $dbx_img
end
