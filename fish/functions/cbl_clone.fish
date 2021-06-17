#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_clone -d "Clone certain repos for ClangBuiltLinux testing and development"
    for arg in $argv
        switch $arg
            case boot-utils tc-build
                set url https://github.com/ClangBuiltLinux/$arg.git
                set dest $CBL_GIT/$arg
            case linux
                set url https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/
                set dest $CBL_SRC/$arg
            case linux-next
                set url https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/
                set dest $CBL_SRC/$arg
            case linux-stable
                set url https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/
                set dest $CBL_SRC/$arg
            case wsl2
                set url git@github.com:nathanchance/WSL2-Linux-Kernel
                set dest $CBL_BLD/wsl2
        end
        if not test -d $dest
            mkdir -p (dirname $dest)
            git clone $url $dest; or return
            switch $arg
                case wsl2
                    git -C $dest remote add -f --tags mainline https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git
                    git -C $dest remote add -f --tags next https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
                    git -C $dest remote add -f --tags microsoft https://github.com/microsoft/WSL2-Linux-Kernel
                    git -C $dest remote add -f --tags sami https://github.com/samitolvanen/linux
                    git -C $dest config rerere.enabled true
                    git -C $dest config status.aheadBehind false
            end
        end
    end
end
