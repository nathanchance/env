#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function in_container -d "Checks if command is being run in a container"
    if test -n "$container"; or test -f /run/.containerenv; or test -f /.dockerenv
        return 0
    end

    return 1
end
