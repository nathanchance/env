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

    # If the current working directory starts with '/home', it needs to be
    # translated into a path that the container can use.
    if string match -qr ^$HOME $PWD
        set container_folder (string replace $HOME /run/host$HOME $PWD)
    else
        set container_folder $PWD
    end

    machinectl shell -q $user_host $SHELL -C "cd $container_folder" $mchsh_args
end
