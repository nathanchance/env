#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function start_tmux -d "Start tmux under certain conditions (for use in config.fish)"
    # If we are in a login shell...
    status is-login
    # and we are not in a graphical environment (implies a terminal application with tabs)...
    and not set -q DISPLAY
    # and we are not in WSL (implies Windows Terminal, which has tabs)...
    and not set -q WSLENV
    # and we are not already in a tmux environment...
    and not set -q TMUX
    # and we have it installed,
    and command -q tmux
    # attempt to attach to a session named "main" while detaching everyone
    # else or create a new session if one does not already exist
    and tmxa
end
