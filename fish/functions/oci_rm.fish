#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function oci_rm -d "Wrapper for oci_rm.py"
    in_container_msg -h; or return

    $PYTHON_SCRIPTS_FOLDER/oci_rm.py $argv
end
