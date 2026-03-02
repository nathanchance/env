#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function transfer_mod_db -d "Transfer modprobed.db to specified IP address"
    if test (count $argv) -eq 0
        set ip (get_ip main)
    else
        set ip $argv[1]
    end
    scp $HOME/.config/modprobed.db nathan@$ip:/tmp
end
