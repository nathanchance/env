#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
exec git am $ENV_FOLDER/pkgbuilds/linux-next-llvm/0001-Revert-IB-qib-Fix-null-pointer-subtraction-compiler-.patch

exec git pll --no-edit sami clang-cfi
"
end
