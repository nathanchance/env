#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_gen_boot_utils_json -d "Generate /tmp/boot-utils.json"
    crl -o /tmp/boot-utils.json https://api.github.com/repos/ClangBuiltLinux/boot-utils/releases/latest
end
