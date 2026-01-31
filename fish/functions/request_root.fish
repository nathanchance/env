#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function request_root -d "Wrapper for requesting root access with an explicit message"
    header "Requesting root access"

    echo "Reason: $argv"

    run0 true
end
