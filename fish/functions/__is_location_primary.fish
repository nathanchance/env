#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function __is_location_primary -d "Checks if current machine is a primary machine (workstation, server)"
    contains $LOCATION $PRIMARY_LOCATIONS
end
