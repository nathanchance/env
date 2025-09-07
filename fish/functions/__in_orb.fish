#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function __in_orb -d "Check if running within an OrbStack machine on macOS"
    set -q MAC_FOLDER
end
