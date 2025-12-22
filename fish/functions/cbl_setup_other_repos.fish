#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_setup_other_repos -d "Download other ClangBuiltLinux repos"
    begin
        cbl_clone_repo llvm-project
        and set folder $CBL_SRC_D/llvm-project
        and if not string match -qr ^nathanchance (git -C $folder remote)
            pushd $folder
            and gh repo fork --remote --remote-name nathanchance
            and git remote update nathanchance
            and popd
        end
    end
    or return

    set repos_cbl_github \
        actions-workflows \
        boot-utils \
        ClangBuiltLinux.github.io \
        containers \
        continuous-integration2 \
        frame-larger-than \
        meeting-notes \
        misc-scripts \
        tc-build
    for repo in $repos_cbl_github
        set folder $CBL_GIT/$repo
        if not test -d $folder
            mkdir -p (path dirname $folder)
            gh repo clone ClangBuiltLinux/$repo $folder
            pushd $folder; or return
            gh repo fork --remote --remote-name nathanchance; or return
            git remote update; or return
            popd; or return
        end
    end

    set repos_personal_github \
        creduce-files \
        llvm-kernel-testing \
        repro-scripts \
        tc-build
    for repo in $repos_personal_github
        switch $repo
            case creduce-files repro-scripts
                set folder $CBL_MISC/$repo
            case llvm-kernel-testing
                set folder $CBL_LKT
            case tc-build
                set folder $CBL_TC_BLD
        end
        if not test -d $folder
            mkdir -p (path dirname $folder)
            switch $repo
                case tc-build
                    set clone_args -- -b personal
            end
            gh repo clone $repo $folder $clone_args
        end
    end

    set tuxmake $CBL_SRC_D/tuxmake
    if not test -d $tumxake
        mkdir -p (path dirname $tuxmake)
        git clone https://github.com/kernelci/tuxmake.git $tuxmake
        and git -C $tuxmake remote add -f nathanchance git@github.com:nathanchance/tuxmake.git
    end
end
