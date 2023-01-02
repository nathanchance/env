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
    if not string match -qr tty (tty)
        start_tmux
    end

    if in_container
        if test "$USE_CBL" = 1
            set -l folder
            for folder in $CBL_QEMU_BIN $CBL_TC_BNTL $CBL_TC_LLVM
                fish_add_path -gm $folder
            end
        end
    else
        gpg_key_cache
        tmux_ssh_fixup
    end

    fish_add_path -aP /usr/local/sbin /usr/sbin /sbin

    if test -d $HOME/.cargo/bin
        fish_add_path -ag $HOME/.cargo/bin
    end
end

if command -q fd
    set -gx FZF_DEFAULT_COMMAND "fd --type file --follow --hidden --exclude .git --color always"
    set -agx FZF_DEFAULT_OPTS --ansi
end

if command -q zoxide
    zoxide init --hook prompt fish | source
end

# Make sure that sourcing config.fish always returns 0
true
