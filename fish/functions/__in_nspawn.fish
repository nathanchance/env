#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function __in_nspawn -d "Test if currently in a systemd-nspawn container"
    __run_py_util_func (status function | string replace __ '')
end
