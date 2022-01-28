#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function lei -d "Runs lei in a Podman container"
    in_container_msg -h; or return

    if command -q podman
        podman run \
            --interactive \
            --rm \
            --tty \
            --volume="$HOME/mail:/mail" \
            --volume="$HOME/.cache/lei:/root/.cache/lei" \
            --volume="$HOME/.config/lei:/root/.config/lei" \
            --volume="$HOME/.local/share/lei:/root/.local/share/lei" \
            $GHCR/lei $argv; or print_error "lei failed to run, does 'boci lei' need to be run?"
    end
end
