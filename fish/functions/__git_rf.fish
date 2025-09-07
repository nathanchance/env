#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __git_rf -d "git reset file"
    for arg in $argv
        switch $arg
            case -q --quiet
                set -a git_ch_args $arg
            case '*'
                set -a files $arg
        end
    end

    git reset -- $files &>/dev/null
    and git checkout $git_ch_args -- $files
end
