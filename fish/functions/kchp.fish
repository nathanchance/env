#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function kchp -d "Shorthand for scripts/checkpatch.pl"
    if test -n "$CHECKPATCH"
        set checkpatch $CHECKPATCH
    else
        set checkpatch scripts/checkpatch.pl
    end

    if not test -x $checkpatch
        __print_error "$checkpatch does not exist or is not executable?"
        return 1
    end

    $checkpatch $argv
end
