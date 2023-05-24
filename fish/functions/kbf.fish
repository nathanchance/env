#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function kbf -d "Prints a build folder specific to the current directory for use with O="
    echo $TMP_BUILD_FOLDER/(basename $PWD)
end
