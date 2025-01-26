#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_clone_repo -d "Clone certain repos for ClangBuiltLinux testing and development"
    for arg in $argv
        set -l branch
        set -l dest
        set -l git_clone_args
        set -l use_repo

        switch $arg
            case boot-utils containers continuous-integration2 tc-build
                set url https://github.com/ClangBuiltLinux/$arg.git
                set dest $CBL_GIT/$arg

            case cbl-ci-gh repro-scripts
                set url https://github.com/nathanchance/$arg.git
                set dest $CBL_MISC/(string replace cbl- "" $arg)

            case common-android-multi
                set use_repo true
                set branch $arg
                set url https://android.googlesource.com/kernel/manifest
                if test -d $NVME_FOLDER
                    set dest $NVME_SRC_FOLDER/$arg
                end
                set local_manifests $GITHUB_FOLDER/local_manifests/$arg.xml

            case cros
                set use_repo true
                set branch stable
                set url https://chromium.googlesource.com/chromiumos/manifest
                if test -d $NVME_FOLDER
                    set dest $NVME_SRC_FOLDER/$arg
                end
                set additional_repos https://chromium.googlesource.com/chromium/tools/depot_tools.git

            case binutils linux linux-next linux-stable llvm-project
                clone_repo_from_bundle {,$CBL_SRC_D/}$arg
                or return

                continue

            case linux-fast-headers
                set git_clone_args -b sched/headers
                set url https://git.kernel.org/pub/scm/linux/kernel/git/mingo/tip.git/

            case llvm-android
                set use_repo true
                set branch llvm-toolchain
                set url https://android.googlesource.com/platform/manifest
                if test -d $NVME_FOLDER
                    set dest $NVME_SRC_FOLDER/$arg
                end

            case '*'
                print_error "$arg not supported explicitly, skipping!"
                continue
        end

        if test -z "$dest"
            set dest $CBL_SRC_D/$arg
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

            if test -n "$use_repo"
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
                        ln -fsv $local_manifest .repo/local_manifests/(path basename $local_manifest)
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
                case tc-build
                    git -C $dest remote add -f nathanchance https://github.com/nathanchance/tc-build
            end
        end
    end
end
