#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_clone_repo -d "Clone certain repos for ClangBuiltLinux testing and development"
    for arg in $argv
        set -l dest

        switch $arg
            case boot-utils tc-build
                set url https://github.com/ClangBuiltLinux/$arg.git
                set dest $CBL_GIT/$arg
            case linux
                set url https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/
            case linux-next
                set url https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/
            case linux-stable
                set url https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/
            case llvm-project
                set url https://github.com/llvm/llvm-project
            case wsl2
                set url git@github.com:nathanchance/WSL2-Linux-Kernel
                set dest $CBL_BLD/wsl2
        end

        if test -z "$dest"
            set dest $CBL_SRC/$arg
        end

        if not test -d $dest
            mkdir -p (dirname $dest)
            git clone $url $dest; or return
            switch $arg
                case llvm-project
                    if test "$LOCATION" = server
                        git -C $dest remote add -f nathanchance git@github.com:nathanchance/llvm-project.git
                        git -C $dest remote add -f origin-ssh git@github.com:llvm/llvm-project.git
                        ln -frsv $dest/llvm/utils/git/pre-push.py $dest/.git/hooks/pre-push
                    end
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
