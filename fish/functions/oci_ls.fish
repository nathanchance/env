#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function oci_ls -d "Shows OCI containers and images"
    in_container_msg -h; or return

    header Containers
    podman container ls --all

    header Images
    podman image ls --all
end
