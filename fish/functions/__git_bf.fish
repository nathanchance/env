#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor
# Portions taken from forgit::checkout::branch (https://github.com/wfxr/forgit)
# Copyright (C) 2017-2022 Wenxuan Zhang <wenxuangm@gmail.com>

function __git_bf -d "Use fzf on git branch output"
    set preview "git log {1} --graph --pretty=format:'-%C(auto)%h%d %s %C(black)%C(bold)%cr%Creset' --color=always --abbrev-commit --date=relative"
    set fzf_opts \
        --ansi \
        --header-lines=1 \
        --multi \
        --no-mouse \
        --no-sort \
        --preview \"$preview\" \
        --tiebreak=index

    git branch --all --color=always | \
        LC_ALL=C sort -k1.1,1.1 -rs | \
        FZF_DEFAULT_OPTS="$fzf_opts" fzf | awk '{print $1}'
end
