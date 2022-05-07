#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function clone_aur_repos -d "Clone repos from AUR to build packages locally"
    set packages \
        binfmt-qemu-static \
        modprobed-db \
        opendoas-sudo \
        slack-desktop \
        shellcheck-bin \
        qemu-user-static-bin \
        visual-studio-code-bin

    for package in $packages
        set repo $AUR_FOLDER/$package
        if not test -d $repo
            mkdir -p (dirname $repo)
            git clone https://aur.archlinux.org/$package.git $repo
        end
    end
end
