#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbxc -d "Shorthand for 'distrobox create'"
    in_container_msg -h; or return

    set add_args --pids-limit=-1

    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case -e --env -v
                set next (math $i + 1)
                set -a add_args $arg $argv[$next]
                set i $next

            case -s --skip-cbl
                set skip_cbl true

            case --ephemeral
                set mode ephemeral

            case --env='*' --volume='*'
                set -a add_args $arg

            case --root -Y --yes
                set -a dbx_args $arg

            case --volume
                set next (math $i + 1)
                set -a dbx_args $arg $argv[$next]
                set i $next

            case dev/'*' gcc-'*' llvm-'*'
                set img $GHCR/$arg
                set name (string replace / - $arg)

            case dev-'*'
                set img $GHCR/(string replace - / $arg)
                set name $arg

            case '*'
                set -a dbx_cmds $arg
        end
        set i (math $i + 1)
    end

    # If not in ephemeral mode, use 'distrobox create'
    if not set -q mode
        set mode create
    end

    # If no image was specified, default to the one for the architecture
    if not set -q img
        set img $GHCR/(get_dev_img)
        set name (string replace / - (get_dev_img))
    end

    set -a dbx_args -i $img
    if test "$mode" = create
        set -a dbx_args -n $name
        if dbx create --help &| grep -q -- --no-entry
            set -a dbx_args --no-entry
        end
    end

    # If we are using a development image AND it is the default one for our
    # architecture (to avoid weird dynamic linking failures), use the binaries
    # in $CBL by default
    if test "$img" = $GHCR/(get_dev_img); and not set -q skip_cbl
        set -a add_args --env=USE_CBL=1
    end

    # If we are going to use an Arch Linux container and the host is using
    # Reflector to update the mirrorlist, mount the mirrorlist into the
    # container so it can enjoy quick updates
    if test "$img" = $GHCR/dev/arch; and test -f /etc/xdg/reflector/reflector.conf
        set -a add_args --volume=/etc/pacman.d/mirrorlist:/etc/pacman.d/mirrorlist:ro
    end

    if test "$mode" = create
        set -p dbx_args -a "$add_args"
    else
        set -p dbx_args '-a "'$add_args'"'
    end

    dbx $mode $dbx_args $dbx_img $dbx_cmds
end
