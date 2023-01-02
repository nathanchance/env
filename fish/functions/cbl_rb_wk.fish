#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_rb_wk -d "Rebase WSL2 kernel on latest linux-next"
    switch $LOCATION
        case hetzner-server workstation wsl
            set src $CBL_BLD/wsl2
        case '*'
            print_error "cbl_rb_wk is not supported by $LOCATION"
            return
    end

    for arg in $argv
        switch $arg
            case -s --skip-mainline
                set skip_mainline true
        end
    end

    git -C $src ru; or return

    for branch in $branches
        git -C $src ch $branch; or return
        git -C $src rb -i next/master; or return
    end

    git -C $src ch next; or return
    git -C $src rh next/master

    if test "$skip_mainline" != true
        set remotebranches mainline:master
    end
    # Disabled for now: https://git.kernel.org/linus/2105a92748e83e2e3ee6be539da959706bbb3898
    # set -a remotebranches sami:clang-cfi
    for remotebranch in $remotebranches
        if not git -C $src pll --no-edit (string split -f1 ":" $remotebranch) (string split -f2 ":" $remotebranch)
            rg "<<<<<<< HEAD" $src; and return
            git -C $src aa
            git -C $src c; or return
        end
    end

    set -a branches dxgkrnl
    git -C $src ml --no-edit $branches; or return
    git -C $src cp (git -C $src log --merges -1 --format=%H origin/HEAD)..(git -C $src sh -s --format=%H origin/HEAD); or return
    $src/bin/build.fish; or return
end
