#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function in_container -d "Checks if command is being run in a container"
    run_py_util_func (status function)
end
