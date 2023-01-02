#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function oci_pull -d "Downloads OCI container images from GitHub"
    switch $LOCATION
        case hetzner-server workstation
            set images \
                dev/{arch,fedora,ubuntu} \
                gcc-$GCC_VERSIONS_KERNEL \
                llvm-$LLVM_VERSIONS_KERNEL

        case '*'
            set images \
                (get_dev_img) \
                llvm-$LLVM_VERSION_TOT \
                llvm-$LLVM_VERSION_STABLE
    end

    podman pull $GHCR/$images
end
