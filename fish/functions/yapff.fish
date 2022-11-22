#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function yapff -d "yapf + fzf"
    if test (count $argv) -gt 0
        set files $argv
    else
        set files (fd -e py | fzf --header "Files to format" --multi --preview 'fish -c "bat {}"')
        test -z "$files"; and return 0
    end

    yapf $files
end
