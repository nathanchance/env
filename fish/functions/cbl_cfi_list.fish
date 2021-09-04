#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# [PATCH v2] ASoC: Intel: boards: Fix CONFIG_SND_SOC_SDW_MOCKUP select
exec git b4 am https://lore.kernel.org/r/20210802212409.3207648-1-nathan@kernel.org/

# [PATCH] iwlwifi: mvm: Fix bitwise vs logical operator in iwl_mvm_scan_fits()
# exec git b4 am https://lore.kernel.org/r/20210814234248.1755703-1-nathan@kernel.org/

# [PATCH] lib/zstd: Fix bitwise vs logical operators
# exec git b4 am https://lore.kernel.org/r/20210815004154.1781834-1-nathan@kernel.org/

# [PATCH][next] net/mlx5: Bridge: Fix uninitialized variable err
exec git b4 am https://lore.kernel.org/r/20210818142558.36722-1-colin.king@canonical.com/

# [PATCH][linux-next] net/mlx5: Bridge, fix uninitialized variable in mlx5_esw_bridge_port_changeupper()
exec git b4 am https://lore.kernel.org/r/20210818155210.14522-1-tim.gardner@canonical.com/

# [PATCH] scsi: st: Add missing break in switch statement in st_ioctl()
exec git b4 am https://lore.kernel.org/r/20210817235531.172995-1-nathan@kernel.org/

# [PATCH][next] io_uring: Fix a read of ununitialized pointer tctx
exec git b4 am https://lore.kernel.org/r/20210903113535.11257-1-colin.king@canonical.com/

exec git pll --no-edit sami clang-cfi
"
end
