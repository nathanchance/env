#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function crl -d "Shorthand for 'curl -LSs'" -w curl
    curl -LSs $argv
end
