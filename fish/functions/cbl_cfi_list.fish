#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# [PATCH] iwlwifi: mvm: Fix bitwise vs logical operator in iwl_mvm_scan_fits()
# exec git b4 am https://lore.kernel.org/r/20210814234248.1755703-1-nathan@kernel.org/

# [PATCH] lib/zstd: Fix bitwise vs logical operators
# exec git b4 am https://lore.kernel.org/r/20210815004154.1781834-1-nathan@kernel.org/

# [net-next 03/15] net/mlx5: Bridge, fix uninitialized variable usage
exec git b4 am -P _ https://lore.kernel.org/r/20210902190554.211497-4-saeed@kernel.org/

# [PATCH] scsi: st: Add missing break in switch statement in st_ioctl()
exec git b4 am https://lore.kernel.org/r/20210817235531.172995-1-nathan@kernel.org/

exec git pll --no-edit sami clang-cfi
"
end
