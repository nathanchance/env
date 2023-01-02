#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function fish_format -d "Format all fish files in directory with fish_indent"
    fd -e fish -x fish_indent -w
end
