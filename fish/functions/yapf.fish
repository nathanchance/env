#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function yapf -d "Call yapf with additional default arguments"
    uvx yapf \
        --in-place \
        --parallel \
        $argv
end
