#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function print_no_werror_cfgs -d "Print disabled -Werror Kconfig values for KCONFIG_ALLCONFIG"
    printf 'CONFIG_%s=n\n' {DRM_,}WERROR
end
