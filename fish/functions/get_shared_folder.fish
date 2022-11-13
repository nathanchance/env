#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function get_shared_folder -d "Pivot folder from $MAIN_FOLDER to $SHARED_FOLDER"
    if test -d $SHARED_FOLDER
        string replace $MAIN_FOLDER $SHARED_FOLDER $argv
    else
        echo $argv
    end
end
