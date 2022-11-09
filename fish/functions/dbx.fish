#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbx -d "Calls distrobox based on where it is installed"
    run_cmd distrobox $argv
end
