#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function tuxmake -d "Calls tuxmake based on how it is available"
    run_cmd (status function) $argv
end
