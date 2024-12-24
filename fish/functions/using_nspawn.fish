#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function using_nspawn -d "Checks if host is using systemd-nspawn for development container"
    PYTHONPATH=$PYTHON_FOLDER python3 -c 'import lib.utils, sys; sys.exit(0 if lib.utils.using_nspawn() else 1)'
end
