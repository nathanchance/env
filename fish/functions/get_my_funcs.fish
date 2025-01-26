#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function get_my_funcs -d "Get a list of functions defined in $ENV_FOLDER/fish/functions"
    path basename $ENV_FOLDER/fish/functions/*.fish | path change-extension ''
end
