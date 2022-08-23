#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function oci_pull -d "Downloads OCI container images from GitHub"
    switch $LOCATION
        case hetzner-server workstation
            set images \
                dev/{arch,fedora,ubuntu} \
                gcc-{5,6,7,8,9,1{0,1}} \
                lei \
                llvm-1{1,2,3,4,5} \
                makepkg
        case '*'
            set images (get_dev_img) llvm-15
    end

    podman pull $GHCR/$images
end
