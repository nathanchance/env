#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function start_ssh_agent -d "Launch an ssh agent only if it has not already been launched"
    for arg in $argv
        switch $arg
            case -f --force
                set force true
        end
    end
    if not set -q force
        status is-interactive; or return 0
    end
    command -q ssh-add; or return 0

    set ssh_key $HOME/.ssh/id_ed25519
    if not test -r "$ssh_key"
        return
    end

    ssh-add -l &>/dev/null
    switch $status
        case 1
            ssh-add $ssh_key
        case 2
            set ssh_agent_file $HOME/.ssh/.ssh-agent.fish

            if test -r $ssh_agent_file
                cat $ssh_agent_file | source >/dev/null
            end

            ssh-add -l &>/dev/null
            switch $status
                case 1
                    ssh-add $ssh_key
                case 2
                    begin
                        umask 066
                        ssh-agent -c >$ssh_agent_file
                    end
                    cat $ssh_agent_file | source >/dev/null
                    ssh-add $ssh_key
            end
    end
end
