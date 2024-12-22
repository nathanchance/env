#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

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
            case --
                set end_of_args true
                set -a dbx_cmd_args $arg
            case '*'
                if set -q end_of_args
                    set -a dbx_cmd_args $arg
                else
                    set dbx_img $arg
                end
        end
        set i (math $i + 1)
    end

    if not set -q dbx_img
        set dbx_img (dev_img)
    end

    if test (count $add_args) -gt 0
        set dbx_args -a "$add_args"
    end

    dbx enter $dbx_args $dbx_img $dbx_cmd_args
end
