#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

set -e fish_user_paths

start_ssh_agent

if test "$LOCATION" = mac
    fish_add_path -m /opt/homebrew/bin
    fish_add_path -m /opt/homebrew/sbin

    set -gx MANPATH /opt/homebrew/share/man

    set -gx INFOPATH /opt/homebrew/share/info

    set -gx SHELL /opt/homebrew/bin/fish
else
    # If /var/tmp/tmux-1000 is a mountpoint, it means we are in a systemd-nspawn
    # container. If TMUX is not already set, we should set it so that we can
    # interact with the host's tmux server. This needs to be done before the
    # call to start_tmux below so that a tmux session is not started in the
    # container.
    set -l tmux_sock_dir /var/tmp/tmux-1000
    set -l tmux_sock $tmux_sock_dir/default
    if mountpoint -q $tmux_sock_dir
        and not set -q TMUX
        and test -S $tmux_sock
        and tmux -S $tmux_sock list-sessions &>/dev/null
        set -gx TMUX $tmux_sock
    end

    set -l tty (tty)
    if not string match -qr tty $tty; and status is-interactive
        start_tmux
    end

    if in_container
        if test (cat /etc/use-cbl 2>/dev/null; or echo 0) -eq 1
            for item in $CBL_QEMU_BIN $CBL_TC_BNTL $CBL_TC_LLVM
                fish_add_path -gm $item
            end
        end

        if not test -e /etc/ephemeral; and not set -q GPG_TTY
            set -gx GPG_TTY $tty
            gpg_key_cache
        end
    else
        gpg_key_cache
        tmux_ssh_fixup
    end

    if test -d $OPT_ORB_GUEST
        fish_add_path -g $OPT_ORB_GUEST/bin-hiprio
        fish_add_path -aP $OPT_ORB_GUEST/bin
        fish_add_path -aP $OPT_ORB_GUEST/data/bin/cmdlinks
    end

    fish_add_path -aP /usr/local/sbin /usr/sbin /sbin
    # https://wiki.archlinux.org/index.php/Perl_Policy#Binaries_and_scripts
    fish_add_path -aP /usr/bin/{site,vendor,core}_perl
end

if command -q fd
    set -gx FZF_DEFAULT_COMMAND "fd --type file --follow --hidden --exclude .git --color always"
    set -agx FZF_DEFAULT_OPTS --ansi
end

if command -q zoxide; and status is-interactive
    zoxide init --hook prompt fish | source
end

if test -d $CARGO_HOME/bin
    fish_add_path -ag $CARGO_HOME/bin
end

# Make sure that sourcing config.fish always returns 0
true
