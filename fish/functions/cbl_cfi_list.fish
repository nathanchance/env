#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_cfi_list -d "Print 'git rebase --interactive' patch list for linux-next CFI tree"
    echo "
exec fish -c 'git ap $ENV_FOLDER/pkgbuilds/linux-next-llvm/1c1046581f1a3809e075669a3df0191869d96dd1-v2.patch; and git ac -m 1c1046581f1a3809e075669a3df0191869d96dd1-v2.patch'

exec fish -c 'git ap $ENV_FOLDER/pkgbuilds/linux-next-llvm/amd-Wmacro-redefined.patch; and git ac -m 1c1046581f1a3809e075669a3df0191869d96dd1-v2.patch'

exec git pll --no-edit sami tip/clang-cfi
"
end
