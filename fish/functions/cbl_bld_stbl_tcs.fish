#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_bld_stbl_tcs -d "Build stable versions of LLVM for building the Linux kernel"
    set -lx PATH $PATH

    set tc_bld $CBL_GIT/tc-build

    rm -rf $tc_bld/install
    $tc_bld/build-binutils.py; or return
    set -p PATH $tc_bld/install/bin

    for llvm_version in $CBL_LLVM_VERSIONS
        set llvm_folder $CBL_STOW_LLVM/$llvm_version
        set -l tc_bld_args

        if not test -x $llvm_folder/bin/clang
            switch $llvm_version
                case 10.0.1
                    set -a tc_bld_args --targets (grep "AArch64;ARM" $tc_bld/build-llvm.py | string split -f 2 '"' | sed 's/RISCV;//')
                case 11.1.0
                    # Empty on purpose to avoid the following assignment
                case '*'
                    # LLVM 10.0.1 and 11.1.0 have assertion failures after Linux 5.12
                    set -a tc_bld_args --assertions
            end

            $tc_bld/build-llvm.py \
                --branch llvmorg-$llvm_version \
                --install-folder $llvm_folder \
                --pgo kernel-defconfig \
                $tc_bld_args; or return
        end
        if not test -x $llvm_folder/bin/as
            $tc_bld/build-binutils.py --install-folder $llvm_folder; or return
        end
    end
end
