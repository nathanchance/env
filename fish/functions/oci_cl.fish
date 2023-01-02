#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function oci_cl -d "Clean untagged OCI images"
    in_container_msg -h; or return

    set images (podman image list &| rg "<none>" &| awk '{print $3}')

    if test -n "$images"
        podman image rm $images
    end
end
