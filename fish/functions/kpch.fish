#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function kpch -d "Run checkpatch.pl and get_maintainer.pl on a patch"
    __in_tree kernel; or return
    if string match -qr b4/ (git bn)
        set b4_branch true
    end

    if test (count $argv) -eq 0
        if set -q b4_branch
            if b4 prep --help &| string match -qr -- '--show-info \[PARAM\]'
                set range (b4 prep --show-info series-range)
            else
                set range (b4 prep --show-info | string match -gr '(?:start|end)-commit:\s+([a-z0-9]{40})' | string join ..)
            end
            kchp -g $range
        else
            set rev HEAD~1..HEAD
        end
    else
        set rev $argv[1]
    end

    if not set -q b4_branch
        for sha in (git log --format=%H --no-merges --reverse $rev)
            set title Commit (git cite $sha)
            set header (for i in (seq 1 (string length "$title")); printf "-"; end)
            printf "\n%s\n%s\n%s\n\n" $header "$title" $header

            kchp -g $sha
            git fp -1 --stdout $sha | kgtm
        end
    end
end
