#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function transfer_mod_db -d "Transfer modprobed.db to $MAIN_REMOTE_IP"
    scp $HOME/.config/modprobed.db nathan@$MAIN_REMOTE_IP:/tmp
end
