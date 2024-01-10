#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_upd_stable -d "Update ClangBuiltLinux stable trees"
    for tree in linux-stable-$CBL_STABLE_VERSIONS
        header "Updating $tree"

        pushd $CBL_BLD_P/$tree
        or return

        if is_tree_dirty
            git stash
            set pop true
        else
            set -e pop
        end

        set old_sha (git sha)

        git pull -r
        or return

        if test (git sha) != $old_sha
            cbl_ptchmn -s
        end

        if set -q pop
            git stash pop
        end

        popd
    end
end
