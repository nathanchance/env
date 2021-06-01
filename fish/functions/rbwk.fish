#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function rbwk -d "Rebase WSL2 kernel on latest linux-next"
    switch $LOCATION
        case server wsl
            set src $CBL_BLD/wsl2
        case '*'
            print_error "rbwk is not supported by $LOCATION"
            return
    end

    git -C $src ru; or return

    set branches dxgkrnl
    for branch in $branches
        git -C $src ch $branch; or return
        git -C $src rb -i next/master; or return
    end

    git -C $src ch next; or return
    git -C $src rh next/master

    for remotebranch in mainline:master sami:clang-cfi
        if not git -C $src pll --no-edit (string split -f1 ":" $remotebranch) (string split -f2 ":" $remotebranch)
            rg "<<<<<<< HEAD" $src; and return
            git -C $src aa
            git -C $src c; or return
        end
    end

    git -C $src ml --no-edit $branches; or return
    git -C $src cp (git -C $src lo --merges -1 --format=%H origin/HEAD)..(git -C $src sh -s --format=%H origin/HEAD); or return
    $src/bin/build.fish; or return
end
