#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function oci_pull -d "Downloads OCI container images from GitHub"
    switch $LOCATION
        case hetzner-server workstation
            set images \
                dev/{arch,fedora,ubuntu} \
                gcc-(seq 5 12) \
                llvm-(seq 11 16)
        case '*'
            set images (get_dev_img) llvm-1{5,6}
    end

    podman pull $GHCR/$images
end
