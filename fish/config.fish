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
    if not string match -qr tty (tty); and status is-interactive
        start_tmux
    end

    if in_container
        # distrobox may add duplicates to PATH, clean it up :/
        # https://github.com/89luca89/distrobox/issues/1145
        set --local --path deduplicated_path
        set --local item

        for item in $PATH
            if not contains $item $deduplicated_path
                set -a deduplicated_path $item
            end
        end
        set --export --global --path PATH $deduplicated_path

        if test "$USE_CBL" = 1
            for item in $CBL_QEMU_BIN $CBL_TC_BNTL $CBL_TC_LLVM
                fish_add_path -gm $item
            end
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
end

if command -q fd
    set -gx FZF_DEFAULT_COMMAND "fd --type file --follow --hidden --exclude .git --color always"
    set -agx FZF_DEFAULT_OPTS --ansi
end

if command -q zoxide
    zoxide init --hook prompt fish | source
end

if test -d $CARGO_HOME/bin
    fish_add_path -ag $CARGO_HOME/bin
end

# Make sure that sourcing config.fish always returns 0
true
