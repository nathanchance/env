#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function bgit -d "Build git from source"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    ihub; or return

    header "Building git"

    set src $SRC_FOLDER/git
    if not test -d $src
        mkdir -p (dirname $src)
        git clone https://git.kernel.org/pub/scm/git/git.git $src; or return
    end
    git -C $src clean -fxdq
    git -C $src pull --rebase

    if test -z "$PREFIX"
        set PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow
    set prefix $stow/packages/git/(date +%F-%H-%M-%S)-(git -C $src show -s --format=%H)

    if string match -q -r x86 (uname -m)
        set march -march=native
    end
    time make \
        -C $src \
        -j(nproc) \
        CFLAGS="$march -O2 -pipe -fstack-protector-strong -fno-plt" \
        LDFLAGS="-Wl,-O1,--sort-common,--as-needed,-z,relro,-z,now" \
        INSTALL_SYMLINKS=1 \
        NO_PERL_CPAN_FALLBACKS=1 \
        USE_LIBPCRE2=1 \
        prefix=$prefix \
        all install; or return

    ln -fnrsv $prefix $stow/git-latest
    stow -d $stow -R -v git-latest

    set -p PATH (dirname $stow)/bin
    command -v git
    git --version
end
