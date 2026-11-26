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
    # Check cached status within current shell
    if test "$USE_LOCAL_MIRROR" = 0
        return 1
    end
    if test "$USE_LOCAL_MIRROR" = 1
        return 0
    end
    # Add quick escape hatch for Hetzner to avoid dynamic check below
    if string match -eq mirror.hetzner.com <?/etc/pacman.d/mirrorlist
        set -gx USE_LOCAL_MIRROR 0
        return 1
    end
    # Perform two cheap checks up front to catch majority of cases
    if string match -eq $LOCAL_PACMAN_MIRROR <?/etc/pacman.d/mirrorlist
        set -gx USE_LOCAL_MIRROR 1
        return 0
    end
    if test -f /etc/dnf/repos.override.d/00-local-mirror.repo
        set -gx USE_LOCAL_MIRROR 1
        return 0
    end
    # Perform dynamic check as last resort
    set ping_cmd \
        ping -c1
    if test $LOCATION = mac
        set -a ping_cmd -t1
    else
        set -a ping_cmd -w1
    end
    if $ping_cmd $LOCAL_MIRROR_IP &>/dev/null
        set -gx USE_LOCAL_MIRROR 1
        return 0
    end
    set -gx USE_LOCAL_MIRROR 0
    return 1
end
