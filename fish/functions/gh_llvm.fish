#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function gh_llvm -d "Shorthand for 'gh -R llvm/llvm-project'" -w gh
    gh -R llvm/llvm-project $argv
end
