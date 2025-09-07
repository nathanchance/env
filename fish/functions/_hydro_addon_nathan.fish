#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function _hydro_addon_nathan -d "Hydro prompt customizations"
    # New line to make prompt a little more spacious
    printf '\\\\n'

    # Signal if we are in a Python virtual environment
    if __in_venv
        printf '%b(%s) ' (set_color 4B8BBE) (path basename $VIRTUAL_ENV)
    end

    if __in_deb_chroot
        printf '%b(chroot:%s) ' (set_color yellow) (cat /etc/debian_chroot)
    end

    # Print symbol if we are in a container (like default toolbox prompt)
    if __in_nspawn
        if set incoming (findmnt -n -o FSROOT /run/host/incoming | path sort -u)
            set container_str '('(string split -f 2 -m 1 -r / $incoming)')'
        else if set image_id (string match -gr 'IMAGE_ID="?([^"]+)' </usr/lib/os-release)
            if test -e /etc/ephemeral
                set image_id "$image_id^"
            end
            set container_str "($image_id)"
        end
    end
    if set -q container_str
        printf '%b%s ' (set_color AF8700) $container_str
    end

    # SSH connection check
    if test "$SSH_CONNECTION" != ""
        set in_ssh true
    else if command -q tmux; and set -q TMUX
        # For whatever reason, there are times where SSH_CONNECTION does
        # not get updated in the environment by tmux so check that here
        if tmux show-env &| string match -qr SSH_CONNECTION=
            set in_ssh_true
        end
    end

    # Print user@host if we are in a container or a SSH session
    if __in_container; or __in_orb; or test "$in_ssh" = true
        printf '%b%s' (set_color yellow) $USER
        printf '%b@%s ' (set_color green) $hostname
    end

    printf '\n'
end
