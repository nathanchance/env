#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function tmuxp -d "Calls tmuxp based on how it is available"
    if __is_system_binary tmuxp
        # installed via distro, just call directly
        command tmuxp $argv
    else
        # installed in $BIN_FOLDER, need to point PYTHONPATH to it
        env PYTHONPATH=$BIN_FOLDER/tmuxp tmuxp $argv
    end
end
