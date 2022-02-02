#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_bf -d "Use fzf on git branch output"
    git branch --format="%(refname:short)" | fzf -m
end
