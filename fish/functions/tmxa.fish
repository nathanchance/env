#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function tmxa -d "Attach to a tmux session if it exists, start a new one if not"
    if test -z "$TMUX"
        tmux new-session -AD -s main
    end
end
