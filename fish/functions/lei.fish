#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function lei -d "Runs lei in a Podman container"
    in_container_msg -h; or return

    if command -q podman
        set fish_trace 1
        podman run \
            --interactive \
            --rm \
            --tty \
            --volume="$MAIL_FOLDER:/mail" \
            --volume="$LEI_FOLDER/cache:/root/.cache/lei" \
            --volume="$LEI_FOLDER/config:/root/.config/lei" \
            --volume="$LEI_FOLDER/share:/root/.local/share/lei" \
            $GHCR/lei $argv; or print_error "lei failed to run, does 'boci lei' need to be run?"
    end
end
