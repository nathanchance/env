#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function haste -d "Upload to a haste-server"
    if test (count $argv) -gt 0
        set input $argv[1]
    else
        set haste_tmp (mktemp)
        cat /dev/stdin | while read line
            echo "$line" >>$haste_tmp
        end
        set input $haste_tmp
    end

    if test -z "$HASTE_URL"
        set HASTE_URL https://paste.myself5.de
    end

    set result (curl -sf --data-binary @"$input" $HASTE_URL/documents)
    echo $HASTE_URL/raw/(echo $result | jq -r .key)

    if set -q haste_tmp
        rm -rf $haste_tmp
    end
end
