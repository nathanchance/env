#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function ssh_vm -d "ssh into a VM running via cbl_vmm.py"
    if test (count $argv) -eq 0
        set port 8022
    else
        set port $argv[1]
        set cmd $argv[2..-1]
    end

    if not grep -q "^\[localhost\]:$port" $HOME/.ssh/known_hosts
        set ssh_args \
            -o "StrictHostKeyChecking no"
    end

    set ssh_cmd \
        ssh $ssh_args -p $port localhost $cmd
    print_cmd $ssh_cmd
    $ssh_cmd
end
