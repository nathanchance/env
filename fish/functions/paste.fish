#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function paste -d "Upload to paste.rs"
    if test (count $argv) -gt 0
        set file $argv[1]
        if test -f $file
            set input $argv[1]
        else
            print_error "$file does not exist!"
            return 1
        end
    else
        set input /dev/stdin
    end

    curl --data-binary @$input https://paste.rs/
end
