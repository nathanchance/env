#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function updfull -d "Update host machine, shell environment, and main distrobox container"
    upd -y \
        env \
        fisher \
        os \
        vim; or return

    if command -q podman; and dbx list &| grep -q (get_dev_img)
        dbxe -- "fish -c 'upd -y'"
    end
end
