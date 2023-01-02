#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function kgtm -d "Shorthand for scripts/get_maintainer.pl"
    if not test -x scripts/get_maintainer.pl
        print_error "get_maintainer.pl does not exist"
        return 1
    end
    scripts/get_maintainer.pl --scm $argv
end
