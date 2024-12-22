#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function dev_img_gh -d "Get the default development image from the GitHub Container Registry"
    echo $GHCR/(dev_img | string replace - /)
end
