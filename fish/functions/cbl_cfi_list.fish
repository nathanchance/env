#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# [PATCH] ice: Fix clang -Wimplicit-fallthrough in ice_pull_qvec_from_rc()
x b4 shazam -l -s https://lore.kernel.org/r/20211019014203.1926130-1-nathan@kernel.org/

# [PATCH net-next] net/mlx5: Add esw assignment back in mlx5e_tc_sample_unoffload()
x b4 shazam -l -s https://lore.kernel.org/r/20211027153122.3224673-1-nathan@kernel.org/

x git pll --no-edit sami tip/clang-cfi
"
end
