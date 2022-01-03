#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellori

function oci_img_exists -d "Check if an OCI image exists in podman image list"
    podman image list -f "reference=$argv" &| grep -q "$argv"
end
