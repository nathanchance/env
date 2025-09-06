#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function cbl_ci_gen_series -d "Regenerate series files in CBL CI repo"
    for dir in $CBL_GIT/continuous-integration2/patches/*
        pushd $dir
        or return

        path sort *.patch >series

        popd
    end
end
