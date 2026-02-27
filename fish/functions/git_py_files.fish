#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function git_py_files -d "Get Python files checked into current repository for linting"
    # Get list of files, specifically excluding this one, as it is a false
    # positive due to the command used :)
    set files (git ls-files | path filter -t link -v | string match -rv (status function).fish)

    # Sort after ripgrep because sorting within ripgrep reduces parallelism
    rg -l '#!/usr/bin/(env )?(python|-S uv)' $files 2>/dev/null | path sort
end
