#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function vw -d "View file with bat"
    for arg in $argv
        switch $arg
            case -c --copy
                set -a bat_args --style plain
            case '*'
                set -a files $arg
        end
    end

    bat \
        --color always \
        --paging always \
        $bat_args \
        $files
end
