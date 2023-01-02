#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function in_container_msg -d "Reports an error based on where command is attempting to be run"
    for arg in $argv
        switch $arg
            case -c --container
                if in_container
                    return 0
                else
                    print_error "Command needs to be run in a container!"
                    return 1
                end
            case -h --host
                if in_container
                    print_error "Command needs to be run in the host OS!"
                    return 1
                else
                    return 0
                end
        end
    end
end
