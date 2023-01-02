#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function stripall -d "Strips all files that are not already stripped"
    for file in (fd -t file . $argv -x file | grep 'not stripped' | cut -d: -f1)
        strip $file
    end
end
