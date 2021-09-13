#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
exec git am $ENV_FOLDER/pkgbuilds/linux-next-llvm/0001-IB-qib-Fix-type-check-in-QIB_DIAGC_ATTR.patch

exec git pll --no-edit sami clang-cfi
"
end
