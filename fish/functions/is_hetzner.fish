#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function is_hetzner -d "Checks if current running machine is a Hetzner machine"
    if test $LOCATION = hetzner # duh
        return 0
    end
    PYTHONPATH=$PYTHON_SETUP_FOLDER python3 -c 'from arch import is_hetzner; import sys; sys.exit(0 if is_hetzner() else 1)'
end
