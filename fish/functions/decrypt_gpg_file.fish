#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function decrypt_gpg_file -d "Decrypts a GPG file into a location"
    gpg_key_cache
    if test (count $argv) -gt 1
        set output $argv[2]
    else
        set output $HOME/.$argv[1]
    end
    mkdir -p (dirname $output)
    gpg --batch --yes --pinentry-mode loopback --output $output --decrypt $ENV_FOLDER/configs/common/$argv[1].gpg
end
