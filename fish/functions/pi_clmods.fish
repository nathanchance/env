#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function pi_clmods -d "Clean up old modules on Raspberry Pi"
    for dir in /lib/modules/*+
        set -a fd_args -E (basename $dir)
    end
    set folders (fd -d 1 $fd_args -E (uname -r) . /lib/modules)

    set rm_cmd \
        sudo rm -frv $folders
    print_cmd $rm_cmd
    $rm_cmd
end
