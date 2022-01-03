#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function updoci -d "Downloads OCI container images from GitHub"
    switch $LOCATION
        case server
            set images \
                dev/{arch,fedora,ubuntu} \
                gcc-{5,6,7,8,9,1{0,1}} \
                lei \
                llvm-1{1,2,3,4} \
                makepkg
        case '*'
            switch (uname -m)
                case aarch64
                    set images dev/fedora llvm-14
                case x86_64
                    set images dev/arch llvm-14
            end
    end

    podman pull $GHCR/$images
end
