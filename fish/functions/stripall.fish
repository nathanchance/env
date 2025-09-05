#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function stripall -d "Strips all files that are not already stripped"
    fd -t file . $argv -x file | string match -er 'not stripped' | string split -f 1 : | while read -l file
        strip $file
    end
end
