#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function gen_systemd_env -d "Generate $HOME/.config/environment.d file for running scripts as services"
    set env_file $HOME/.config/environment.d/50-personal-env.conf
    mkdir -p (path dirname $env_file)

    for var in CBL_SRC_M NAS_FOLDER PYTHON_SCRIPTS_FOLDER
        printf "%s=%s\n" $var (nspawn_path -H $$var)
    end >$env_file
end
