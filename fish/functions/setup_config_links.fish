#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 Nathan Chancellor

function setup_config_links -d "Set up configuration symlinks from $ENV_FOLDER/configs"
    # Configuration files (vim, tmux, etc)
    set configs $ENV_FOLDER/configs
    ln -fnrsv $configs/tmux/.tmux.conf.common $HOME/.tmux.conf.common
    ln -fnrsv $configs/tmux/.tmux.conf.container $HOME/.tmux.conf.container
    if test "$LOCATION" = vm
        ln -fnrsv $configs/tmux/.tmux.conf.vm $HOME/.tmux.conf
    else
        ln -fnrsv $configs/tmux/.tmux.conf.regular $HOME/.tmux.conf
    end
    mkdir -p $HOME/.config/tio
    ln -frsv $configs/local/tio.config $HOME/.config/tio/config
    vim_setup

    # Terminal profiles
    if set -q DISPLAY
        if __is_installed konsole
            set konsole_share $HOME/.local/share/konsole
            mkdir -p $konsole_share
            ln -frsv $configs/local/Nathan.profile $konsole_share/Nathan.profile
            ln -frsv $configs/local/snazzy.colorscheme $konsole_share/snazzy.colorscheme
        end

        if __is_installed xfce4-terminal
            set xfce_share $HOME/.local/share/xfce4/terminal/colorschemes
            mkdir -p $xfce_share
            ln -frsv $configs/local/snazzy.theme $xfce_share
        end
    end
end
