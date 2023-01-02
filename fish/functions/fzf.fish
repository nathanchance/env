#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function fzf -d "Calls fzf based on how it is available"
    set -q TMUX; and set cmd fzf-tmux
    set -q cmd; or set cmd fzf
    run_cmd $cmd $argv
end
