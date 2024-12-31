#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

# 'machinectl shell' does not return the error code of the called process, so this should only be used interactively.
function mchsh -d "Wrapper around 'machinectl shell'"
    in_container_msg -h
    or return

    for arg in $argv
        switch $arg
            case '*@*'
                set user_host $arg
            case '*'
                set -a mchsh_args $arg
        end
    end
    if not set -q user_host
        set user_host $USER@(dev_img)
    end
    if not set -q mchsh_args
        set mchsh_args -l
    end

    # Use fish's --init-commands to drop into the current working directory,
    # instead of $HOME, which is not really useful if working on the host and
    # wanting to drop into the guest to work.
    machinectl shell -q $user_host $SHELL -C 'cd '(nspawn_path -c $PWD) $mchsh_args
end
