#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function kgenp -d "Generate patches from a git tree to send via git send-email"
    in_kernel_tree; or return

    set mfc (git mfc)

    git fp --base $mfc^ $argv $mfc^..
end
