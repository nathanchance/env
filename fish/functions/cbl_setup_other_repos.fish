#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_setup_other_repos -d "Download other ClangBuiltLinux repos"
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
            mkdir -p (dirname $folder)
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
        set folder $CBL/$repo
        if not test -d $folder
            mkdir -p (dirname $folder)
            switch $repo
                case tc-build
                    set clone_args -- -b personal
            end
            gh repo clone $repo $folder $clone_args
        end
    end

    set pi_scripts $CBL_BLD/pi-scripts
    if not test -d $pi_scripts
        mkdir -p (dirname $pi_scripts)
        gh repo clone pi-scripts $pi_scripts
    end

    set tuxmake $CBL_SRC/tuxmake
    if not test -d $tumxake
        mkdir -p (dirname $tuxmake)
        git clone https://gitlab.com/Linaro/tuxmake.git $tuxmake
    end

    cbl_clone_repo wsl2
end
