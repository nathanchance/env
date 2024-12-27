#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function using_nspawn -d "Checks if host is using systemd-nspawn for development container"
    run_py_util_func (status function)
end
