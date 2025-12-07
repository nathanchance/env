#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function vim_setup -d "Setup vim configuration files"
    set env_vim $ENV_FOLDER/configs/common/vim
    set ln ln -fsv
    if test (__get_distro) != macos
        set -a ln -r
    end

    # Install indentation and plugin files
    for folder in indent plugin
        set dest $HOME/.vim/$folder
        test -L $dest; and continue

        mkdir -p (path dirname $dest)
        $ln $env_vim/$folder $dest
    end

    # Install .vimrc
    $ln $env_vim/.vimrc $HOME/.vimrc

    # Download and update plugins
    upd vim
end
