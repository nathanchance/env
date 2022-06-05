#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function updfull -d "Update host machine, shell environment, and main distrobox container"
    upd -y \
        env \
        fisher \
        os \
        vim
    and dbxe -- "fish -c 'upd -y'"
end
