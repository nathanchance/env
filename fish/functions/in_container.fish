#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function in_container -d "Checks if command is being run in a container"
    for arg in $argv
        switch $arg
            case -q --quiet
                set quiet true
        end
    end

    if test -z "$container"; or not test -f /run/.containerenv
        if test "$quiet" != "true"
            print_error "This command needs to be run in a container!"
        end
        return 1
    end

    return 0
end
