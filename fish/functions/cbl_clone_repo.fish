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
        set -l use_repo

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
            case common-android-multi
                set use_repo true
                set branch $arg
                set url https://android.googlesource.com/kernel/manifest
                set local_manifests $GITHUB_FOLDER/local_manifests/$arg.xml
            case cros
                set use_repo true
                set branch stable
                set url https://chromium.googlesource.com/chromiumos/manifest
                if test -d $NVME_FOLDER
                    set dest $NVME_FOLDER/data/$arg
                end
                set additional_repos https://chromium.googlesource.com/chromium/tools/depot_tools.git
            case linux linux-next linux-stable
                clone_lnx_repo {,$CBL_SRC/}$arg
                or return
                continue
            case linux-fast-headers
                set git_clone_args -b sched/headers
                set url https://git.kernel.org/pub/scm/linux/kernel/git/mingo/tip.git/
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
            if test -n "$use_repo"
                mkdir -p $dest
            else
                mkdir -p (dirname $dest)
            end

            if test -n "$bundle"; and test -e $bundle
                clone_from_bundle $bundle $dest $url $branch; or return
            else if test -n "$use_repo"
                pushd $dest

                repo init -u $url -b $branch
                and repo sync -c --force-sync -j4

                if test -n "$local_manifests"
                    mkdir .repo/local_manifests

                    for local_manifest in $local_manifests
                        if not test -e $local_manifest
                            print_error "Supplied local manifest ('$local_manifest') does not exist!"
                            return 1
                        end
                        ln -fsv $local_manifest .repo/local_manifests/(basename $local_manifest)
                    end
                end

                if test -n "$additional_repos"
                    for additional_repo in $additional_repos
                        git clone $additional_repo
                        or return
                    end
                end

                popd
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
