#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function kpch -d "Run checkpatch.pl and get_maintainer.pl on a patch"
    in_kernel_tree; or return

    if test (count $argv) -eq 0
        set rev HEAD~1..HEAD
    else
        set rev $argv[1]
    end

    for sha in (git log --format=%H --no-merges --reverse $rev)
        set title Commit (git kf $sha)
        set header (for i in (seq 1 (string length "$title")); printf "-"; end)
        printf "\n%s\n%s\n%s\n\n" $header "$title" $header

        kchp -g $sha
        git fp -1 --stdout $sha | kgtm
    end
end
