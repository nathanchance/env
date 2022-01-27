#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

if in_container -q
    set -l folder
    for folder in /qemu /tc /binutils /llvm
        fish_add_path -gm $folder/bin
    end
else
    gpg_key_cache
    start_ssh_agent
    tmux_ssh_fixup

    set -e fish_user_paths; or true
end

if command -q zoxide
    zoxide init --hook prompt fish | source
end
