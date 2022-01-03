#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function shellcheck -d "Runs shellcheck through the system or podman depending on how it is available"
    if command -q shellcheck
        command shellcheck $argv
    else if test -x $BIN_FOLDER/shellcheck
        $BIN_FOLDER/shellcheck $argv
    else if command -q podman
        podman run \
            --rm \
            --tty \
            --volume="$PWD:/mnt" \
            docker.io/koalaman/shellcheck:stable \
            $argv
    else
        print_error "shellcheck could not be found. Run 'upd shellcheck' to install it."
        return 1
    end
end
