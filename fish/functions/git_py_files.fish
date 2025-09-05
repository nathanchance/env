#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function git_py_files -d "Get Python files checked into current repository for linting"
    # Get list of files, specifically excluding this one, as it is a false
    # positive due to the command used :) We pass through realpath and uniq
    # to handle files that may be symlinked multiple times like korg_tc,
    # which can make linting annoying otherwise
    set files (git ls-files | string match -rv (status function).fish | path resolve | uniq | string replace "$PWD/" '')

    # Sort after ripgrep because sorting within ripgrep reduces parallelism
    rg -l '#!/usr/bin/env python' $files | sort
end
