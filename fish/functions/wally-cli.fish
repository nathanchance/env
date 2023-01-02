#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function wally-cli -d "Calls wally-cli based on how it is available"
    run_cmd (status function) $argv
end
