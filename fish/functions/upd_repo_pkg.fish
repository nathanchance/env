#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function upd_repo_pkg -d "Update package in personal Arch Linux repo"
    set database nathan.db.tar.gz
    if not test -f $database
        print_error "Working directory should have $database!"
        return 1
    end

    repo-add $database $argv

    if test -L nathan.db
        rm -v nathan.db
        cp -v nathan.db{.tar.gz,}
    end

    if test -L nathan.files
        rm -v nathan.files
        cp -v nathan.files{.tar.gz,}
    end
end
