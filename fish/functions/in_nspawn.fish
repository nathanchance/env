#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function in_nspawn -d "Test if currently in a systemd-nspawn container"
    run_py_util_func (status function)
end
