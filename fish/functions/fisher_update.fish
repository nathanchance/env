#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function fisher_update -d "Run 'fisher update' after setting up _fisher_plugins for environment"
    adjust_fisher_paths -c
    fisher update $argv
    adjust_fisher_paths -H
end
