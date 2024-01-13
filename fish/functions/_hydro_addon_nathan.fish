#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function _hydro_addon_nathan -d "Hydro prompt customizations"
    # New line to make prompt a little more spacious
    printf '\\\\n'

    # Signal if we are in a Python virtual environment
    if in_venv
        printf '%b(%s) ' (set_color 4B8BBE) (basename $VIRTUAL_ENV)
    end

    if in_deb_chroot
        printf '%b(chroot:%s) ' (set_color yellow) (cat /etc/debian_chroot)
    end

    # Print symbol if we are in a container (like default toolbox prompt)
    if in_container
        printf '%b%s ' (set_color magenta) §
    end

    # SSH connection check
    if test "$SSH_CONNECTION" != ""
        set in_ssh true
    else if command -q tmux; and set -q TMUX
        # For whatever reason, there are times where SSH_CONNECTION does
        # not get updated in the environment by tmux so check that here
        if tmux show-env | grep -q SSH_CONNECTION=
            set in_ssh_true
        end
    end

    # Print user@host if we are in a container or a SSH session
    if in_container; or in_orb; or test "$in_ssh" = true
        printf '%b%s' (set_color yellow) (id -un)
        printf '%b@%s ' (set_color green) $hostname
    end

    printf '\n'
end
