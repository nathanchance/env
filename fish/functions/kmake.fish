#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function kmake -d "Wrapper for kmake.py"
    if not in_container; and test -z "$OC"
        print_error "This needs to be run in a container! Override this check with 'OC=1'."
        return 1
    end
    $PYTHON_SCRIPTS_FOLDER/kmake.py $argv
end
