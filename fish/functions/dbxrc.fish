#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function dbxrc -d "Recreate a distrobox container"
    dbxr $argv
    and dbxc $argv
    and dbxe $argv -- $PYTHON_SCRIPTS_FOLDER/upd_distro.py -y
end
