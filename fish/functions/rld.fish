#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function rld -d "Reload fish configuration"
    fisher update $ENV_FOLDER/fish 1>/dev/null
    source $__fish_config_dir/config.fish
end
