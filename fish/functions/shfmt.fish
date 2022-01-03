#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function shfmt -d "Runs shfmt through the system or podman depending on how it is available"
    if command -q shfmt
        command shfmt $argv
    else if test -x $BIN_FOLDER/shfmt
        $BIN_FOLDER/shfmt $argv
    else if command -q podman
        podman run \
            --rm \
            --tty \
            --volume="$PWD:/mnt" \
            --workdir /mnt \
            docker.io/mvdan/shfmt \
            $argv
    else
        print_error "shfmt could not be found. Run 'upd shfmt' to install it."
        return 1
    end
end
