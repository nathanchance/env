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
                case scp transfer
                    set ssh_cmd scp
                case '*'
                    if test "$ssh_cmd" = scp
                        if set -q src
                            set dst $arg
                        else
                            set src $arg
                        end
                    else
                        set -a cmd $arg
                    end
            end
        end
    end
    set -q ssh_cmd; or set ssh_cmd ssh
    set -q port; or set port 8022
    set -q user; or set user nathan

    set user_host $user@localhost

    if not grep -q "^\[localhost\]:$port" $HOME/.ssh/known_hosts
        set -a cmd_args \
            -o "StrictHostKeyChecking no"
    end

    switch $ssh_cmd
        case scp
            if not set -q src
                print_error "No source and destination provided?"
                return 1
            end
            if not set -q dst
                print_error "No destination provided?"
                return 1
            end

            if string match -qr ^: $src
                set src $user_host$src
            else if string match -qr ^: $dst
                set dst $user_host$dst
            else
                print_error "Neither source nor destination have a colon to mark remote file?"
                return 1
            end

            set -a cmd_args \
                -P $port \
                -r \
                $src \
                $dst

        case ssh
            set -a cmd_args \
                -p $port \
                $user_host \
                $cmd
    end

    set full_cmd \
        $ssh_cmd $cmd_args
    print_cmd $full_cmd
    $full_cmd
end
