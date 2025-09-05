#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cdf -d "cd + fzf"
    if command -q eza
        set ls_cmd eza
    else
        set ls_cmd ls
    end

    set dest (fd -t d --color=always | fzf --preview "$ls_cmd {}")

    if test -n "$dest"
        cd $dest
    end
end
