#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# [net 1/7] net/mlx5: Bridge, fix uninitialized variable usage
exec git b4 am -P _ https://lore.kernel.org/r/20210907212420.28529-2-saeed@kernel.org/

# [PATCH] scsi: st: Add missing break in switch statement in st_ioctl()
exec git b4 am https://lore.kernel.org/r/20210817235531.172995-1-nathan@kernel.org/

exec git pll --no-edit sami clang-cfi
"
end
