#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function nspawn_adjust_path -d "Translate $HOME paths into /run/host$HOME paths"
    if string match -qr ^$HOME $argv[1]
        set prefix /run/host
    end

    printf '%s%s\n' $prefix $argv[1]
end
