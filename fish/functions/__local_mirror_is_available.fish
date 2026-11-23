#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function __local_mirror_is_available -d "Check if access to local mirror is available"
    # Add variables to customize behavior on demand
    if set -q skip_local_mirror
        return 1
    end
    if set -q use_local_mirror
        return 0
    end
    # Add quick escape hatch for Hetzner to avoid dynamic check below
    if string match -eq mirror.hetzner.com <?/etc/pacman.d/mirrorlist
        return 1
    end
    # Perform two cheap checks up front to catch majority of cases
    if string match -eq $LOCAL_PACMAN_MIRROR <?/etc/pacman.d/mirrorlist
        return 0
    end
    if test -f /etc/dnf/repos.override.d/00-local-mirror.repo
        return 0
    end
    # Perform dynamic check as last resort
    echo '[+] Checking for mirror availability'
    if ping -c1 -w3 $LOCAL_MIRROR_IP &>/dev/null
        return 0
    end
    return 1
end
