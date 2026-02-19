#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

set -e fish_user_paths

# Only add uv installation folder to PATH if it was not present as a system binary
if not command -q uv
    fish_add_path -ag $UV_INSTALL_DIR
    command -q uv
    and uv generate-shell-completion fish | source
end
fish_add_path -ag $UV_PYTHON_BIN_DIR $UV_TOOL_BIN_DIR

fish_add_path -ag $PYTHON_BIN_FOLDER

start_ssh_agent

switch $LOCATION
    case mac
        fish_add_path -m /opt/homebrew/bin
        fish_add_path -m /opt/homebrew/sbin

        set -gx MANPATH /opt/homebrew/share/man
        set -gx INFOPATH /opt/homebrew/share/info
        set -gx SHELL /opt/homebrew/bin/fish

    case '*'
        fish_add_path -aP /usr/local/sbin /usr/sbin /sbin
        # https://wiki.archlinux.org/index.php/Perl_Policy#Binaries_and_scripts
        fish_add_path -aP /usr/bin/{site,vendor,core}_perl

        # This needs to come before any uses of 'command' to ensure commands are found.
        # They also need to come after the system's bin folders so that they do not
        # override distribution packages, which get continuous updates, unlike upd,
        # which just happen "whenever I remember".
        fish_add_path -aP (path filter -d $BIN_FOLDER{,/*/bin})

        # If /var/tmp/tmux-1000 is a mountpoint, it means we are in a systemd-nspawn
        # container. If TMUX is not already set, we should set it so that we can
        # interact with the host's tmux server. This needs to be done before the
        # call to __start_tmux below so that a tmux session is not started in the
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
            __start_tmux
        end

        if __in_container
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
            __tmux_ssh_fixup
        end

        if test -d $OPT_ORB_GUEST
            fish_add_path -g $OPT_ORB_GUEST/bin-hiprio
            fish_add_path -aP $OPT_ORB_GUEST/bin
            fish_add_path -aP $OPT_ORB_GUEST/data/bin/cmdlinks
        end
end

if command -q fd
    set -gx FZF_DEFAULT_COMMAND "fd --type file --follow --hidden --exclude .git --color always"
    set -agx FZF_DEFAULT_OPTS --ansi
end

if command -q zoxide; and status is-interactive
    # Maintain separate databases for host and container so that
    # there are not duplicate paths from /run/host/home and /home
    set -l zo_cfg $HOME/.local/share/zoxide
    if __in_container
        set -gx _ZO_DATA_DIR $zo_cfg/container
    else
        set -gx _ZO_DATA_DIR $zo_cfg/host
    end

    zoxide init --hook prompt fish | source
end

if test -d $CARGO_HOME/bin
    fish_add_path -ag $CARGO_HOME/bin
end

# Undo fish 4.1 change to keybindings
# https://github.com/fish-shell/fish-shell/commit/2bb5cbc95943b0168c8ceb5b639391299e767e72
bind alt-backspace backward-kill-word
bind alt-left backward-word
bind alt-right forward-word

# Make sure that sourcing config.fish always returns 0
true
