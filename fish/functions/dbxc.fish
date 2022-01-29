#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbxc -d "Shorthand for 'distrobox create'"
    in_container_msg -h; or return

    set add_args --pids-limit -1

    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case -e --env -v
                set next (math $i + 1)
                set -a add_args $arg $argv[$next]
                set i $next

            case --env='*' --volume='*'
                set -a add_args $arg

            case --volume
                set next (math $i + 1)
                set -a dbx_args $arg $argv[$next]
                set i $next

            case dev/'*' gcc-'*' llvm-'*'
                set img $GHCR/$arg
                set -a dbx_args -i $img -n (string replace "/" "-" $arg)

            case dev-'*'
                set img $GHCR/(string replace "-" "/" $arg)
                set -a dbx_args -i $img -n $arg
        end
        set i (math $i + 1)
    end

    # If we are using a development image AND it is the default one for our
    # architecture (to avoid weird dynamic linking failures), bind mount some
    # folders into convenient to use locations.
    switch (uname -m)
        case aarch64
            set def_img $GHCR/dev/fedora
        case x86_64
            set def_img $GHCR/dev/arch
    end
    if test "$img" = "$def_img"
        set -a add_args -e USE_CBL=1
    end

    dbx create -a "$add_args" $dbx_args $dbx_img
end
