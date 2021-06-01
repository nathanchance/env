#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function iduf -d "Install duf as a prebuilt from GitHub"
    header "Installing duf"

    set repo muesli/duf
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end
    set VERSION (string replace 'v' '' $VERSION)

    set arch (uname -m)
    switch (uname -m)
        case aarch64
            if command -q dpkg
                switch (dpkg --print-architecture)
                    case armhf
                        set arch armv7
                    case '*'
                        set arch arm64
                end
            else
                set arch arm64
            end
        case armv7l
            set arch armv7
    end

    set work_dir (mktemp -d)

    crl https://github.com/$repo/releases/download/v$VERSION/duf_"$VERSION"_linux_$arch.tar.gz | tar -C $work_dir -xzf -; or return
    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow

    install -Dvm755 $work_dir/duf $stow/prebuilts/bin/duf

    stow -d $stow -R -v prebuilts

    rm -rf $work_dir
end
