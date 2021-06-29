#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ccache_setup -d "Setup ccache size and compression"
    switch $LOCATION
        case desktop laptop pi vm
            set size 15
        case generic wsl
            set size 25
        case server
            set size 150
    end
    ccache --max-size="$size"G >/dev/null
    ccache --set-config=compression=true
    ccache --set-config=compression_level=9
end
