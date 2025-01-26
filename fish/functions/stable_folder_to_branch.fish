#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function stable_folder_to_branch -d "Convert 'linux-stable-<num>.<num>' into 'linux-<num>.<num>.y'"
    string replace stable- '' (path basename $argv).y
end
