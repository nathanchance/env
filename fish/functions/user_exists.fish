#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function user_exists -d "Checks if a user exists on the machine"
    getent passwd $argv &>/dev/null
end
