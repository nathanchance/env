#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __git_ua -d "git remote update + action"
    set action $argv[1]

    switch $action
        case rh rbi
        case '*'
            __print_error "Action needs to be the first argument!"
            return 1
    end

    switch (count $argv)
        case 1
            set remote (git rn)
            set branch (git bn)

        case 2
            set rmb $argv[2]
            if string match -qr '[a-zA-Z0-9-_]+/.*' $rmb
                set remote (string split -f 1 / $rmb)
                set branch (string replace "$remote/" "" $rmb)
            else
                __print_error "Expected <remote>/<branch>!"
                return 1
            end

        case 3
            set remote $argv[2]
            set branch $argv[3]

        case '*'
            __print_error "Too many arguments! Use either <remote>/<branch> or <remote> <branch>."
            return 1
    end

    git ru --prune $remote; or return
    git $action $remote/$branch
end
