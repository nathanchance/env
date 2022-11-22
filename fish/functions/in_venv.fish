#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function in_venv -d "Returns true if in a Python virtual environment"
    # This isn't foolproof but it is good enough
    set -q VIRTUAL_ENV
end
