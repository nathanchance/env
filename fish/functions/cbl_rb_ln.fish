#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_rb_ln -d "Update linux-next with local patches"
    in_kernel_tree; or return

    set first_sha (git mfc)
    set second_sha (git show -s --format=%H (git cb))

    git rh origin/master
    git cherry-pick --gpg-sign $first_sha^..$second_sha
end
