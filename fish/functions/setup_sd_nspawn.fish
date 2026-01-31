#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function setup_sd_nspawn -d "Perform initial systemd-nspawn setup"
    # These platforms will more than likely use tmux so ensure the tmux
    # directory exists with the expected permissions so that sd_nspawn
    # will find it and mount it into the container properly. Even if they
    # do not use tmux, creating the directory and passing it through to
    # the container is not the end of the world, as no socket will exist.
    set tmux_tmp /var/tmp/tmux-(id -u)
    mkdir -p $tmux_tmp
    # tmux checks that the permissions are restrictive
    chmod 700 $tmux_tmp

    request_root "Setting up systemd-nspawn"
    or return

    # Set up files first because that process is quicker than the build
    # process and doas/run0 authorization lasts at least five minutes
    $PYTHON_BIN_FOLDER/sd_nspawn -i
    or return

    mkosi_bld
    or return

    # '--now' is only supported with systemd 253 or newer but AlmaLinux 9 ships 252
    if test (machinectl --version | string match -gr '^systemd (\d+) ') -ge 253
        run0 machinectl enable --now $DEV_IMG
    else
        run0 machinectl enable $DEV_IMG
        and run0 machinectl start $DEV_IMG
    end
end
