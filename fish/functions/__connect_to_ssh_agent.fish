#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function __connect_to_ssh_agent -d "Connect to an ssh-agent and load my SSH key"
    set ssh_key $HOME/.ssh/id_ed25519
    begin
        not set -q SSH_AUTH_SOCK
        and status is-interactive
        or __in_nspawn
        and command -q ssh-add
        and test -f "$ssh_key"
    end
    or return 0

    set possible_ssh_agent_sockets \
        # orbstack
        $OPT_ORB_GUEST/run/host-ssh-agent.sock \
        # Arch / Fedora
        $XDG_RUNTIME_DIR/ssh-agent.socket \
        # Debian
        $XDG_RUNTIME_DIR/openssh_agent

    for ssh_agent_socket in $possible_ssh_agent_sockets
        if test -S $ssh_agent_socket; and test (stat -c %u $ssh_agent_socket) = (id -u)
            set -gx SSH_AUTH_SOCK $ssh_agent_socket
            break
        end
    end
    if not set -q SSH_AUTH_SOCK
        __print_error "No previously started agent available?"
        return 1
    end

    if not set -q TMUX; and not __in_nspawn; and sd_nspawn --is-running
        # This should really be sd_nspawn but for some reason, starting an agent
        # with systemd-run and trying to access it with 'machinectl shell' does
        # not work... oh well, this does :)
        mchsh -c /bin/true
    end

    if not test -e /etc/ephemeral
        ssh-add -l &>/dev/null
        switch $status
            case 0
                return 0
            case 1
                ssh-add $ssh_key
                return
            case '*'
                ssh-add -l
                return
        end
    end
end
