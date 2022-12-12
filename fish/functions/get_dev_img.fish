#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function get_dev_img -d "Print the default development container image for the host architecture"
    switch (uname -m)
        case 'armv7*' i686
            echo dev/suse
        case aarch64
            echo dev/fedora
        case x86_64
            echo dev/arch
    end
end
