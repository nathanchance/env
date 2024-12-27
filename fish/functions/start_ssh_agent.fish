#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function start_ssh_agent -d "Launch an ssh agent only if it has not already been launched"
    if test -S $OPT_ORB_GUEST/run/host-ssh-agent.sock
        set -q SSH_AUTH_SOCK; or set -gx SSH_AUTH_SOCK $OPT_ORB_GUEST/run/host-ssh-agent.sock
        return 0
    end

    for arg in $argv
        switch $arg
            case -f --force
                set force true
        end
    end
    if in_nspawn
        set force true
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
            if in_nspawn
                if test -e /etc/ephemeral
                    set ssh_agent_file /tmp/.ssh-agent.fish
                else
                    set ssh_agent_file $HOME/.ssh/.systemd-nspawn-ssh-agent.fish
                end
            else
                set ssh_agent_file $HOME/.ssh/.ssh-agent.fish
            end

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
