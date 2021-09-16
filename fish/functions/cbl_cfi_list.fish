#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# [PATCH] ptp: ocp: Avoid operator precedence warning in ptp_ocp_summary_show()
exec git b4 am https://lore.kernel.org/netdev/20210916194351.3860836-1-nathan@kernel.org/

exec git pll --no-edit sami clang-cfi
"
end
