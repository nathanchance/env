#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function pretty_print_cmd -d "Print supplied command as if 'fish_trace' was set"
    echo '$ '($ENV_FOLDER/python/pretty_print_cmd.py $argv)
end
