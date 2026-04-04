#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function setup_sd_nspawn -d "Perform initial systemd-nspawn setup"
    request_root "Setting up systemd-nspawn"
    or return

    # Set up files first because that process is quicker than the build
    # process and doas/run0 authorization lasts at least five minutes
    $PYTHON_BIN_FOLDER/sd_nspawn -i
    or return

    run_mkosi
    or return

    # '--now' is only supported with systemd 253 or newer but AlmaLinux 9 ships 252
    if test (machinectl --version | string match -gr '^systemd (\d+) ') -ge 253
        run0 machinectl enable --now $DEV_IMG
    else
        run0 machinectl enable $DEV_IMG
        and run0 machinectl start $DEV_IMG
    end
end
