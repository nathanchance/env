#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cdr -d "Change to root directory of git repo"
    cd (git root)
end
