#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function rbld_usr -d "Rebuild the binaries and scripts in ~/usr"
    if test -z "$PREFIX"
        set -x PREFIX $USR_FOLDER
    end
    set stow $PREFIX/stow

    if test -d $stow
        for package in $stow/{*-latest,git,prebuilts}
            if test -d $package
                stow -d $stow -D -v (basename $package)
            end
        end
    end
    rm -rf $PREFIX/{bin,doc,include,lib,libexec,share}
    mkdir -p $stow

    switch $LOCATION
        case generic
            updbin; or return
            iandroidtools; or return
            ituxmake; or return

        case pi
            bccache; or return
            bgit; or return
            bmake; or return
            biexa; or return
            birg; or return
            bisharkdp all; or return
            btmux; or return

        case server
            switch (get_distro)
                case arch
                    bgit; or return
                    bcvise; or return

                case debian ubuntu
                    updbin; or return
                    bdtc; or return
                    iandroidtools; or return
            end
            iarc; or return
            ituxmake; or return

        case wsl
            switch (get_distro)
                case arch
                    bgit; or return
                    bcvise; or return

                case debian ubuntu
                    updbin; or return
            end
    end

    ib4; or return

    set git_bin $stow/git/bin
    mkdir -p $git_bin
    for command in $ENV_FOLDER/git/*
        ln -fsv $command $git_bin/git-(basename $command)
    end
    stow -d $stow -R -v git

    if test -L $stow/llvm-latest
        stow -d $stow -R -v llvm-latest
    end
end
