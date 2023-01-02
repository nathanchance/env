#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function vim_setup -d "Setup vim configuration files"
    set env_vim $ENV_FOLDER/configs/common/vim

    # Install identification and plugin files
    for folder in ident plugin
        set src $env_vim/$folder
        set dest $HOME/.vim/$folder

        mkdir -p (dirname $dest)
        ln -fsv $src $dest
    end

    # Install .vimrc
    ln -fsv $env_vim/.vimrc $HOME/.vimrc

    # Download and update plugins
    upd vim
end
