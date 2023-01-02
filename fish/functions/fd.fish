#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function fd -d "Calls fd based on how it is available"
    run_cmd (status function) $argv
end
