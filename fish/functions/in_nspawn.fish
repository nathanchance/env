#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function in_nspawn -d "Test if currently in a systemd-nspawn container"
    test (systemd-detect-virt 2>/dev/null; or echo none) = systemd-nspawn
end
