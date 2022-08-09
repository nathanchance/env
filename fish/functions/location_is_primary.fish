#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022 Nathan Chancellor

function location_is_primary -d "Checks if current machine is the primary machine (my workstation)"
    test "$LOCATION" = "$PRIMARY_LOCATION"
end
