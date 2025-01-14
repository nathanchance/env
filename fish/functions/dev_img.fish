#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function dev_img -d "Print the default development container image for the host architecture"
    switch (uname -m)
        case 'armv7*'
            echo dev-debian
        case aarch64
            echo dev-fedora
        case x86_64
            echo dev-arch
    end
end
