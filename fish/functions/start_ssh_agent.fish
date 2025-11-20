#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function start_ssh_agent -d "Launch an ssh agent only if it has not already been launched"
    if test -S $OPT_ORB_GUEST/run/host-ssh-agent.sock
        set -q SSH_AUTH_SOCK
        or set -gx SSH_AUTH_SOCK $OPT_ORB_GUEST/run/host-ssh-agent.sock
        return 0
    end

    for arg in $argv
        switch $arg
            case -f --force
                set force true
        end
    end
    if __in_nspawn
        set force true
    end
    if not set -q force
        status is-interactive
        or return 0
    end
    command -q ssh-add
    or return 0

    set ssh_key $HOME/.ssh/id_ed25519
    if not test -r "$ssh_key"
        return
    end

    ssh-add -l &>/dev/null
    switch $status
        case 1 # Can connect to the ssh-agent, no identities yet
            ssh-add $ssh_key
        case 2 # Cannot connect to the ssh-agent
            set ssh_agent_file $HOME/.ssh/.ssh-agent.fish

            # Attempt to read a previously started agent's file
            if test -r $ssh_agent_file
                cat $ssh_agent_file | source >/dev/null
            end

            ssh-add -l &>/dev/null
            switch $status
                case 1 # Can connect to ssh-agent now, no identities yet
                    ssh-add $ssh_key
                case 2 # No ssh-agent, start a new one and add key
                    set ssh_agent_sock $HOME/.ssh/.ssh-agent.sock
                    rm -fr $ssh_agent_sock
                    begin
                        umask 066
                        ssh-agent -a $ssh_agent_sock -c >$ssh_agent_file
                    end
                    cat $ssh_agent_file | source >/dev/null
                    ssh-add $ssh_key
            end
    end
end
