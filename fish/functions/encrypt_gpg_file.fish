#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function encrypt_gpg_file -d "Encrypts a GPG file into a location"
    gpg_key_cache
    if test (count $argv) -gt 1
        set input $argv[2]
    else
        set input $HOME/.$argv[1]
    end
    gpg --batch --yes --output $ENV_FOLDER/configs/common/$argv[1].gpg --encrypt --recipient natechancellor@gmail.com $input
end
