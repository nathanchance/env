#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function __is_system_binary -d "Checks if command is a system binary (installed from a package manager)"
    set binary $argv[1]
    if not command -q $binary
        # cannot be a system binary if it is not installed
        return 1
    end

    # This is not foolproof but it will cover a good number of cases
    if test $LOCATION = mac
        set regex /opt/homebrew/bin/
    else
        set regex /usr/s?bin/
    end
    command -v $binary | string match -qr ^$regex
end
