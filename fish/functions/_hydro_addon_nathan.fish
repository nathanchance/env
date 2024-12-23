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
    if in_dbx
        # If CONTAINER_ID is a part of the hostname (i.e., distrobox prior to
        # https://github.com/89luca89/distrobox/commit/d626559baaa4e6ccb35b3bb0befc9d46b7aa837e),
        # just show a symbol to know we are in a distrobox.
        if string match -qr ^$CONTAINER_ID $hostname
            set container_str §
        else
            set container_str "($CONTAINER_ID)"
        end
    end
    if in_nspawn
        if set incoming (findmnt -n -o FSROOT /run/host/incoming)
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
        if tmux show-env | grep -q SSH_CONNECTION=
            set in_ssh_true
        end
    end

    # Print user@host if we are in a container or a SSH session
    if in_container; or in_orb; or test "$in_ssh" = true
        printf '%b%s' (set_color yellow) $USER
        printf '%b@%s ' (set_color green) $hostname
    end

    printf '\n'
end
