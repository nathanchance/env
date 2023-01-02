#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function in_kernel_tree -d "Checks if we are in a kernel tree via presence of Makefile"
    if not test -f Makefile
        print_error "You do not appear to be in a kernel tree"
        return 1
    end
end
