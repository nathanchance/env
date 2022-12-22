#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function kmake -d "Run make with all cores and adjust PATH temporarily"
    if not in_container; and test -z "$OC"
        print_error "This needs to be run in a container! Override this check with 'OC=1'."
        return 1
    end
    $USER_PYTHON_FOLDER/kmake.py $argv
end
