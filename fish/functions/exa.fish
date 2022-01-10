#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function exa -d "Runs exa through the system or podman depending on how it is available"
    if command -q exa
        command exa $argv
    else if test -x $BIN_FOLDER/exa
        $BIN_FOLDER/exa $argv
    else
        command ls --color=auto $argv
    end
end
