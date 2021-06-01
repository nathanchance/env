#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ccache_setup -d "Setup ccache size and compression"
    switch $LOCATION
        case generic wsl
            set size 25
        case workstation
            set size 150
        case pi
            set size 15
    end
    ccache --max-size="$size"G >/dev/null
    ccache --set-config=compression=true
    ccache --set-config=compression_level=9
end
