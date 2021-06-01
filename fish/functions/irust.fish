#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function irust -d "Install rust"
    curl https://sh.rustup.rs -sSf | bash -s -- -y --no-modify-path
end
