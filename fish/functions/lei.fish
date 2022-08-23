#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function lei -d "Runs lei though system or podman, depending on how it is available"
    set -lx XDG_CACHE_HOME $XDG_FOLDER/cache
    set -lx XDG_CONFIG_HOME $XDG_FOLDER/config
    set -lx XDG_DATA_HOME $XDG_FOLDER/share

    if command -q lei
        command lei $argv
    else
        in_container_msg -h; or return

        if command -q podman
            set fish_trace 1
            podman run \
                --interactive \
                --rm \
                --tty \
                --volume="$MAIL_FOLDER:$MAIL_FOLDER" \
                --volume="$XDG_CACHE_HOME:/root/.cache" \
                --volume="$XDG_CONFIG_HOME:/root/.config" \
                --volume="$XDG_DATA_HOME:/root/.local/share" \
                $GHCR/lei $argv; or print_error "lei failed to run, does 'oci_bld lei' need to be run?"
        else
            print_error "Cannot run lei!"
            return 1
        end
    end
end
