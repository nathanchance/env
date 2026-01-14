#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function wgt -d "Wrapper for 'wget -q -O -'"
    set wget_args -q
    if not contains -- -O $argv
        set -a wget_args -O -
    end
    set -a wget_args $argv

    wget $wget_args
end
