#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function git_sw -d "git switch with fzf"
    if test (count $argv) -gt 0
        for arg in $argv
            switch $arg
                case -d --detach
                    set -a git_switch_args $arg
                case '*'
                    set ref $arg
            end
        end
        if not set -q ref
            print_error "No ref supplied?"
            return 1
        end
    else
        set ref (git bf)
    end

    if test -n "$ref"
        if string match -qr "^remotes/" $ref
            for remote in (git remote)
                set replace_string "^remotes/$remote/"
                if string match -qr "$replace_string" $ref
                    set -f git_switch_args \
                        -c (string replace -r "$replace_string" "" $ref)
                    break
                end
            end
        end

        git switch $git_switch_args $ref
    end
end
