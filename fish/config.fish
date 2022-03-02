#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

set -e fish_user_paths

start_ssh_agent

if in_container
    if test "$USE_CBL" = 1
        set -l folder
        for folder in $CBL_QEMU_BIN $CBL_TC_BNTL $CBL_TC_LLVM
            fish_add_path -gm $folder
        end
    end
else
    gpg_key_cache
    tmux_ssh_fixup
end

if command -q zoxide
    zoxide init --hook prompt fish | source
end
