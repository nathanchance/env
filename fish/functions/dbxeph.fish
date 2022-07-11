#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function dbxeph -d "Shorthand for 'distrobox ephemeral'"
    dbxc --ephemeral $argv
end
