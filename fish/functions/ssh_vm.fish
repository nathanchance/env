#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function ssh_vm -d "ssh into a VM running via cbl_vmm.py"
    for arg in $argv
        if string match -qr '^\d+$' $arg
            set port $arg
        else
            switch $arg
                case nathan root
                    set user $arg
                case '*'
                    set -a cmd $arg
            end
        end
    end
    set -q user; or set user nathan
    set -q port; or set port 8022

    if not grep -q "^\[localhost\]:$port" $HOME/.ssh/known_hosts
        set ssh_args \
            -o "StrictHostKeyChecking no"
    end

    set ssh_cmd \
        ssh $ssh_args -p $port $user@localhost $cmd
    print_cmd $ssh_cmd
    $ssh_cmd
end
