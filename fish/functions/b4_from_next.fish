#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function b4_from_next
    if test -e Next/Trees
        set parts (fzf <Next/Trees | awk '{print $3}' | string split '#')

        if test (count $parts) -eq 2
            echo "git repo: $parts[1]"
            echo "git branch: $parts[2]"

            read -l -P 'b4 branch arg: ' branch
            b4_prep $parts $branch
        else
            print_error "Malformed parts?"
            echo "parts: $parts"
            return 1
        end
    else
        print_error "Not in a -next tree?"
        return 1
    end
end
