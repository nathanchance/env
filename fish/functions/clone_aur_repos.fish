#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function clone_aur_repos -d "Clone repos from AUR to build packages locally"
    set packages \
        debhelper \
        modprobed-db \
        opendoas-sudo \
        shellcheck-bin

    for package in $packages
        set repo $SRC_FOLDER/packaging/pkg/$package
        if not test -d $repo
            mkdir -p (path dirname $repo)
            git clone https://aur.archlinux.org/$package.git $repo
        end
    end
end
