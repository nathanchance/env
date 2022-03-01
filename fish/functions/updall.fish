#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function updall -d "Update binaries in $BIN_FOLDER"
    for arg in $argv
        switch $arg
            case -n --no-os
                set os false
        end
    end

    if test "$os" != false
        set targets os
    end

    set -a targets \
        arc \
        b4 \
        bat \
        diskus \
        distrobox \
        duf \
        exa \
        fd \
        fzf \
        hyperfine \
        repo \
        rg \
        shellcheck \
        shfmt \
        tuxmake \
        yapf

    upd $targets
end
