#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function ishellcheck -d "Install shellcheck"
    header "Installing shellcheck"

    set repo koalaman/shellcheck
    if test -z "$VERSION"
        set VERSION (glr $repo)
    end

    set work_dir (mktemp -d)/shellcheck-v(string replace 'v' '' $VERSION)

    crl https://github.com/$repo/releases/download/$VERSION/(basename $work_dir).linux.x86_64.tar.xz | tar -C (dirname $work_dir) -xJf -; or return

    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow

    install -Dvm755 $work_dir/shellcheck $stow/prebuilts/bin/shellcheck

    stow -d $stow -R -v prebuilts

    rm -rf $work_dir
end
