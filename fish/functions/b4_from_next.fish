#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function b4_from_next -d "Run b4_prep after interactively selecting a base from Next/Trees"
    if not test -e Next/Trees
        print_error "Not in a -next tree?"
        return 1
    end

    set parts (fzf <Next/Trees | awk '{print $3}' | string split '#')
    if test (count $parts) -ne 2
        print_error "Malformed parts?"
        echo "parts: $parts"
        return 1
    end

    echo "git repo: $parts[1]"
    echo "git branch: $parts[2]"
    read -P 'b4 branch arg: ' branch

    b4_prep $parts $branch
end
