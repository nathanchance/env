#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function gpg_key_usable -d "Checks if GPG is installed and key is in keyring"
    command -q gpg; or return
    gpg --list-secret-keys --keyid-format LONG &| grep -q 1D6B269171C01A96
end
