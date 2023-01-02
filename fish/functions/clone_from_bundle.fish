#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function clone_from_bundle
    if test (count $argv) -ne 4
        print_error "<cb> <folder> <url> <branch>"
        return 1
    end

    set cb $argv[1]
    set folder $argv[2]
    set url $argv[3]
    set branch $argv[4]

    begin
        git clone $cb $folder
        and git -C $folder remote remove origin
        and git -C $folder remote add origin $url
        and git -C $folder remote update origin
        and git -C $folder checkout $branch
    end
end
