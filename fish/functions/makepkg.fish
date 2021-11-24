#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function makepkg -d "Runs makepkg in a container"
    if not test -f PKGBUILD
        print_error "PKGBUILD not found in current working directory!"
        return 1
    end

    podman run \
        --rm \
        --tty \
        --volume=$PWD:/pkg \
        --workdir=/pkg \
        $GHCR/makepkg
end
