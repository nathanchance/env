#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function __in_nspawn -d "Test if currently in a systemd-nspawn container"
    if command -q systemd-detect-virt
        test (systemd-detect-virt -c) = systemd-nspawn
        return
    end
    return 1
end
