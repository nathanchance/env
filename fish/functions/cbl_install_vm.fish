#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function cbl_install_vm -d "Wrapper for install-vm.py"
    in_container_msg -h; or return

    set install_vm_py $CBL_GIT/containers/ci/install-vm.py

    if not test -f $install_vm_py
        cbl_clone_repo containers
    end

    $install_vm_py $argv
end
