#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function updenv -d "Pull updates from env repo and load them into environment"
    git -C $ENV_FOLDER pull -qr; or return
    rld
end
