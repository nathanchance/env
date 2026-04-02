#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_clone_repo -d "Clone certain repos for ClangBuiltLinux testing and development"
    if test -e $HOME/.ssh/id_ed25519
        set codeberg_url ssh://git@codeberg.org
    else
        set codeberg_url https://codeberg.org
    end

    for arg in $argv
        set -l branch
        set -l dest
        set -l git_clone_args
        set -l use_repo

        # Some arguments may have shorthands, expand them before handling
        switch $arg
            case lkt $CBL_LKT
                set arg llvm-kernel-testing
            case $CBL_TC_BLD
                set arg nathanchance/tc-build
        end

        switch $arg
            case b4 kup
                set url https://git.kernel.org/pub/scm/utils/$arg/$arg.git
                set dest $SRC_FOLDER/$arg

            case boot-utils containers continuous-integration2 tc-build
                set url https://github.com/ClangBuiltLinux/$arg.git
                set dest $CBL_GIT/$arg

            case common-android-multi
                set use_repo true
                # The common-android-multi branch has long been dead. Use
                # common-android-mainline as a base to ensure updates to
                # other projects are done properly.
                set branch common-android-mainline
                set url https://android.googlesource.com/kernel/manifest
                if test -d $NVME_FOLDER
                    set dest $NVME_SRC_FOLDER/$arg
                end
                set local_manifests $CODEBERG_FOLDER/local_manifests/$arg.xml

            case cros
                set use_repo true
                set branch stable
                set url https://chromium.googlesource.com/chromiumos/manifest
                if test -d $NVME_FOLDER
                    set dest $NVME_SRC_FOLDER/$arg
                end
                set additional_repos https://chromium.googlesource.com/chromium/tools/depot_tools.git

            case binutils linux linux-next linux-stable llvm-project
                __clone_repo_from_bundle {,$CBL_SRC_D/}$arg
                or return

                continue

            case linux-fast-headers
                set git_clone_args -b sched/headers
                set url https://git.kernel.org/pub/scm/linux/kernel/git/mingo/tip.git/

            case llvm-kernel-testing
                set url $codeberg_url/nathanchance/$arg.git

            case llvm-android
                set use_repo true
                set branch llvm-toolchain
                set url https://android.googlesource.com/platform/manifest
                if test -d $NVME_FOLDER
                    set dest $NVME_SRC_FOLDER/$arg
                end

            case nathanchance/tc-build
                set dest $CBL_TC_BLD
                set git_clone_args -b personal
                set url $codeberg_url/$arg.git

            case repro-scripts
                set url $codeberg_url/nathanchance/$arg.git
                set dest $CBL_MISC/$arg

            case '*'
                __print_error "$arg not supported explicitly, skipping!"
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
                mkdir -p (path dirname $dest)
            end

            if test -n "$use_repo"
                pushd $dest

                repo init -u $url -b $branch
                or return

                if test -n "$local_manifests"
                    mkdir .repo/local_manifests

                    for local_manifest in $local_manifests
                        if not test -e $local_manifest
                            __print_error "Supplied local manifest ('$local_manifest') does not exist!"
                            return 1
                        end
                        ln -fsv $local_manifest .repo/local_manifests/(path basename $local_manifest)
                    end
                end

                repo sync -c --force-sync -j4
                or return

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
                case nathanchance/tc-build
                    git -C $dest remote add -f upstream https://github.com/ClangBuiltLinux/tc-build.git
                case tc-build
                    git -C $dest remote add -f codeberg $codeberg_url/nathanchance/tc-build.git
            end
        end
    end
end
