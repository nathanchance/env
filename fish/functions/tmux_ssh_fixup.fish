#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function tmux_ssh_fixup -d "Fix up SSH_CONNECTION value in tmux"
    # For whatever reason, there are times where SSH_CONNECTION exists in the
    # original shell environment and the tmux environment (as visible with
    # tmux show-env) but not in the shell environment within tmux. It usually
    # happens with tmux is automatically started at boot:
    #
    # $ env | grep SSH_CONNECTION
    #
    # $ tmux show-env | grep SSH_CONNECTION
    # SSH_CONNECTION=192.168.4.54 63192 192.168.4.104 22
    #
    # $ exit
    #
    # $ env | grep SSH_CONNECTION
    # SSH_CONNECTION=192.168.4.54 63192 192.168.4.104 22
    #
    # $ tmux new-session -AD -s main
    #
    # $ env | grep SSH_CONNECTION
    # SSH_CONNECTION=192.168.4.54 63192 192.168.4.104 22
    #
    # So we set it manually here

    if set -q TMUX
        set tmux_ssh_con (tmux show-env | grep SSH_CONNECTION=)
        set fish_ssh_con $SSH_CONNECTION

        if test "$tmux_ssh_con" != "$fish_ssh_con"
            set -gx SSH_CONNECTION (string split -f 2 = $tmux_ssh_con)
        end
    end
end
