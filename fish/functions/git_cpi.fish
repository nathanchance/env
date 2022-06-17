#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function git_cpi -d "Interactive git cherry-pick with forgit"
    forgit::cherry::pick (git bf)
end
