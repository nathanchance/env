#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function oci_rm -d "Remove OCI containers and images"
    in_container_msg -h; or return

    $ENV_FOLDER/python/oci_rm.py $argv
end
