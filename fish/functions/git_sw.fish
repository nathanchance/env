#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function git_sw -d "git switch with fzf"
    if test (count $argv) -gt 0
        set ref $argv
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
