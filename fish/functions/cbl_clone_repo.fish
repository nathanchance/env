#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_clone_repo -d "Clone certain repos for ClangBuiltLinux testing and development"
    set bundles_folder $NAS_FOLDER/bundles

    for arg in $argv
        set -l branch
        set -l bundle
        set -l dest
        set -l git_clone_args

        switch $arg
            case binutils
                set bundle $bundles_folder/$arg.bundle
                set url https://sourceware.org/git/binutils-gdb.git
            case boot-utils containers continuous-integration2 tc-build
                set url https://github.com/ClangBuiltLinux/$arg.git
                set dest $CBL_GIT/$arg
            case cbl-ci-gh repro-scripts
                set url https://github.com/nathanchance/$arg.git
                set dest $CBL/(string replace cbl- "" $arg)
            case linux
                set bundle $bundles_folder/$arg.bundle
                set url https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/
            case linux-fast-headers
                set git_clone_args -b sched/headers
                set url https://git.kernel.org/pub/scm/linux/kernel/git/mingo/tip.git/
            case linux-next
                set bundle $bundles_folder/$arg.bundle
                set url https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git/
            case linux-stable
                set bundle $bundles_folder/$arg.bundle
                set url https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/
            case llvm-project
                set branch main
                set bundle $bundles_folder/$arg.bundle
                set url https://github.com/llvm/llvm-project
            case wsl2
                set url git@github.com:nathanchance/WSL2-Linux-Kernel
                set dest $CBL_BLD/wsl2
            case '*'
                print_error "$arg not supported explicitly, skipping!"
                continue
        end

        if test -z "$dest"
            set dest $CBL_SRC/$arg
        end
        if test -z "$branch"
            set branch master
        end

        if not test -d $dest
            mkdir -p (dirname $dest)
            if test -n "$bundle"; and test -e $bundle
                clone_from_bundle $bundle $dest $url $branch; or return
            else
                git clone $git_clone_args $url $dest; or return
            end
            switch $arg
                case llvm-project
                    switch $LOCATION
                        case hetzner-server workstation
                            git -C $dest remote add -f nathanchance git@github.com:nathanchance/llvm-project.git
                            git -C $dest remote add -f origin-ssh git@github.com:llvm/llvm-project.git
                            ln -frsv $dest/llvm/utils/git/pre-push.py $dest/.git/hooks/pre-push
                    end
                case tc-build
                    git -C $dest remote add -f nathanchance https://github.com/nathanchance/tc-build
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
