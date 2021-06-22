#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function pi_clmods -d "Clean up old modules on Raspberry Pi"
    set fish_trace 1

    for dir in /lib/modules/*+
        set -a fd_args -E (basename $dir)
    end
    set folders (fd -d 1 $fd_args -E (uname -r) . /lib/modules)

    sudo rm -frv $folders
end
