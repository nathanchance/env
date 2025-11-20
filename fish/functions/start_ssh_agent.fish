#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function start_ssh_agent -d "Launch an ssh agent only if it has not already been launched"
    set orb_ssh_agent $OPT_ORB_GUEST/run/host-ssh-agent.sock
    # Check that the socket exists and that it is accessible,
    # otherwise we will need to start a new agent
    if test -S $orb_ssh_agent; and test (stat -c %u $orb_ssh_agent) = (id -u)
        set -q SSH_AUTH_SOCK
        or set -gx SSH_AUTH_SOCK $orb_ssh_agent
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

    set host_ssh_agent_file $HOME/.ssh/.host-ssh-agent.fish
    set host_ssh_agent_sock $HOME/.ssh/.host-ssh-agent.sock
    set container_ssh_agent_file (string replace .host .container $host_ssh_agent_file)
    set container_ssh_agent_sock (string replace .host .container $host_ssh_agent_sock)

    if __in_nspawn
        set ssh_agent_file $container_ssh_agent_file
        set ssh_agent_sock $container_ssh_agent_sock
    else
        set ssh_agent_file $host_ssh_agent_file
        set ssh_agent_sock $host_ssh_agent_sock

        # An unfortunate regression in systemd-nspawn in 258 necessitates
        # using two separate ssh-agent instances :/ I maintain a version of
        # systemd with the problematic patch reverted in Arch Linux currently
        # so this workaround is not needed there.
        # https://github.com/systemd/systemd/issues/39037
        if test (__get_systemd_version) -ge 258; and test (__get_distro) != arch
            set need_separate_ssh_agents true
        else if test (uname) != Darwin
            ln -fnrs $ssh_agent_file $container_ssh_agent_file
        end
    end

    if not set -q SSH_AUTH_SOCK
        ssh-add -l &>/dev/null
        switch $status
            case 1 # Can connect to the ssh-agent, no identities yet
                ssh-add $ssh_key
            case 2 # Cannot connect to the ssh-agent
                # Attempt to read a previously started agent's file
                if test -r $ssh_agent_file
                    cat $ssh_agent_file | source >/dev/null
                end

                ssh-add -l &>/dev/null
                switch $status
                    case 1 # Can connect to ssh-agent now, no identities yet
                        ssh-add $ssh_key
                    case 2 # No ssh-agent, start a new one and add key
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

    if set -q need_separate_ssh_agents; and not set -q TMUX; and sd_nspawn --is-running
        # This should really be sd_nspawn but for some reason, starting an agent
        # with systemd-run and trying to access it with 'machinectl shell' does
        # not work... oh well, this does :)
        mchsh -c /bin/true
    end
end
