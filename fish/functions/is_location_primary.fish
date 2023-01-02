#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function is_location_primary -d "Checks if current machine is the primary machine (my workstation)"
    test "$LOCATION" = "$PRIMARY_LOCATION"
end
