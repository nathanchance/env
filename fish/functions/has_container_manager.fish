#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function has_container_manager -d "Returns true if either docker or podman is installed"
    test "$LOCATION" = mac; and return 1 # OrbStack has a docker wrapper, ignore it
    command -q docker; or command -q podman
end
