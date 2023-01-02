#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function kchp -d "Shorthand for scripts/checkpatch.pl"
    if not test -x scripts/checkpatch.pl
        print_error "checkpatch.pl does not exist"
        return 1
    end
    scripts/checkpatch.pl $argv
end
