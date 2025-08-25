#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function setup_user_systemd_files -d "Install user systemd files"
    set files \
        nas-bundles.{service,timer}

    mkdir -p $HOME/.config/systemd/user
    for file in $ENV_FOLDER/configs/systemd/$files
        ln -fnrsv $file $HOME/.config/systemd/user
        or return
    end

    gen_systemd_env
end
