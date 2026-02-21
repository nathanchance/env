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

    if set -q XDG_RUNTIME_DIR
        set xdg_runtime_folder $XDG_RUNTIME_DIR
    else
        # This should only happen when using 'sd_nspawn -r' with systemd 257
        # or older
        set xdg_runtime_folder /run/user/(id -u)
    end
    set possible_ssh_agent_sockets \
        # orbstack
        $OPT_ORB_GUEST/run/host-ssh-agent.sock \
        # Arch / Fedora
        $xdg_runtime_folder/ssh-agent.socket \
        # Debian
        $xdg_runtime_folder/openssh_agent

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
