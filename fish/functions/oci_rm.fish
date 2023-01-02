#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function oci_rm -d "Remove OCI containers and images"
    in_container_msg -h; or return

    $PYTHON_SCRIPTS_FOLDER/oci_rm.py $argv
end
