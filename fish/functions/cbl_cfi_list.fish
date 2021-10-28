#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# drm/i915: Avoid bitwise vs logical OR warning in snb_wm_latency_quirk()
x fish -c \"curl -LSs 'https://cgit.freedesktop.org/drm/drm-intel/patch/?id=2e70570656adfe1c5d9a29940faa348d5f132199' | git am\"

# [PATCH] ice: Fix clang -Wimplicit-fallthrough in ice_pull_qvec_from_rc()
x b4 shazam -l -s https://lore.kernel.org/r/20211019014203.1926130-1-nathan@kernel.org/

# [PATCH net-next] net/mlx5: Add esw assignment back in mlx5e_tc_sample_unoffload()
x b4 shazam -l -s https://lore.kernel.org/r/20211027153122.3224673-1-nathan@kernel.org/

x git pll --no-edit sami tip/clang-cfi
"
end
