#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function __in_deb_chroot -d "Check if we are in a Debian chroot (usually via schroot)"
    test -r /etc/debian_chroot
end
