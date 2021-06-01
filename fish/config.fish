#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

fish_add_path -m $HOME/.cargo/bin
fish_add_path -m $HOME/.local/bin
fish_add_path -m $USR_FOLDER/bin
gpg_key_cache
ssh_agent
tmux_ssh_fixup
