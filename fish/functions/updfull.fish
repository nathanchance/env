#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function updfull -d "Update host machine, shell environment, and main development container"
    in_container_msg -h
    or return

    for arg in $argv
        switch $arg
            case -s --skip-container
                set os_target os-no-container
        end
    end
    if not set -q os_target
        set os_target os
    end

    upd -y \
        env \
        fisher \
        $os_target \
        vim
end
