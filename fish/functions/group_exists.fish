#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function group_exists -d "Checks if a group exists on the machine"
    getent group $argv &>/dev/null
end
