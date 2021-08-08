#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_upd_stable -d "Update ClangBuiltLinux stable trees"
    for tree in linux-stable-$CBL_STABLE_VERSIONS
        echo "Updating $tree..."
        pushd $CBL_BLD_P/$tree; or return
        git pull -qr; or return
        ptchmn -s
    end
end
