#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
# [PATCH] KVM: x86: avoid warning with -Wbitwise-instead-of-logical
x b4 shazam -l -s https://lore.kernel.org/r/20211015085148.67943-1-pbonzini@redhat.com/

# [PATCH] regulator: lp872x: Remove lp872x_dvs_state
x b4 shazam -l -s https://lore.kernel.org/r/20211019004335.193492-1-nathan@kernel.org/

# [PATCH] ice: Fix clang -Wimplicit-fallthrough in ice_pull_qvec_from_rc()
x b4 shazam -l -s https://lore.kernel.org/r/20211019014203.1926130-1-nathan@kernel.org/

x git pll --no-edit sami tip/clang-cfi
"
end
