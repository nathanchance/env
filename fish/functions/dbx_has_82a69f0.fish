#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function dbx_has_82a69f0 -d "Checks that distrobox is 1.7.0.1 or newer (i.e., contains 82a69f0)"
    # https://github.com/89luca89/distrobox/commit/82a69f0a234e73e447d0ea8c8b3443b84fd31944
    distrobox --version | python3 -c "import re, sys

if not (match := re.search(r'distrobox: ([0-9|.]+)', sys.stdin.read())):
    raise RuntimeError('distrobox version changed?')

distrobox_version = tuple(map(int, match.groups()[0].split('.')))
sys.exit(0 if distrobox_version >= (1, 7, 0, 1) else 1)"
end
