#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function get_my_funcs -d "Get a list of functions defined in $ENV_FOLDER/fish/functions"
    path basename $ENV_FOLDER/fish/functions/*.fish $PYTHON_BIN_FOLDER/* | path change-extension '' | path sort
end
