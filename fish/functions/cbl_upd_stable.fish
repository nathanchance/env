#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_stable -d "Update ClangBuiltLinux stable trees"
    for tree in linux-stable-$CBL_STABLE_VERSIONS
        header "Updating $tree"
        pushd $CBL_BLD_P/$tree; or return
        git pull -r; or return
        cbl_ptchmn -s
    end
end
