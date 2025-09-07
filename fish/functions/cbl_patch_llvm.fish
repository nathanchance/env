#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2025 Nathan Chancellor

function cbl_patch_llvm -d "Apply fixes for known problems from newer environments to LLVM"
    if test (count $argv) -eq 0
        __in_tree llvm
        or return 128

        set llvm_src $PWD
    else
        set llvm_src $argv[1]
    end
    # ensure git commands are always in LLVM repository, not current directory
    set git git -C $llvm_src

    if not set sha ($git sha)
        __print_error "$llvm_src not a git repository??"
        return 128
    end

    # Avoid build issues with newer versions of libstdc++
    if not $git merge-base --is-ancestor 7e44305041d96b064c197216b931ae3917a34ac1 $sha
        $git cherry-pick -n 7e44305041d96b064c197216b931ae3917a34ac1
        or return 128
    end
    # the above patch will implicitly resolve the issue if 2222fddfc0a2 is present
    if not $git merge-base --is-ancestor 2222fddfc0a2ff02036542511597839856289094 $sha
        sed -i '/#include <memory>/i #include <cstdint>' $llvm_src/llvm/lib/Target/X86/MCTargetDesc/X86MCTargetDesc.h
    end

    # https://github.com/llvm/llvm-project/issues/100296
    if $git merge-base --is-ancestor d38c8a7a51227fecdb1f84160f5da4f89c3e25be $sha
        and not $git merge-base --is-ancestor 40b4fd7a3e81d32b29364a1b15337bcf817659c0 $sha
        $git cherry-pick -n 40b4fd7a3e81d32b29364a1b15337bcf817659c0
        or return 128
    end
end
