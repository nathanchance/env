#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2022-2023 Nathan Chancellor

function have_dev_kvm_access -d "Checks if /dev/kvm is usable by the current user"
    python3 -c "import os, sys; sys.exit(0 if os.access('/dev/kvm', os.R_OK | os.W_OK) else 1)"
end
