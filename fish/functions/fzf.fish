#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function fzf -d "Calls fzf based on how it is available"
    set args $argv
    if set -q TMUX
        set -p args --tmux
    end
    run_cmd (status function) $argv
end
