#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function clone_aur_repos -d "Clone repos from AUR to build packages locally"
    set packages \
        modprobed-db \
        opendoas-sudo \
        shellcheck-bin

    for package in $packages
        set repo $AUR_FOLDER/$package
        if not test -d $repo
            mkdir -p (dirname $repo)
            git clone https://aur.archlinux.org/$package.git $repo
        end
    end
end
