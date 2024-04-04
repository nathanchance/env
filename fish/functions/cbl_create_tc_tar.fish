#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function cbl_create_tc_tar -d "Create tarball with latest toolchains in $CBL_TC"
    if test -L (dirname $CBL_TC_BNTL); and test -L (dirname $CBL_TC_LLVM)
        set tar_dst $CBL_TC/latest-cbl-tc.tar.zst
        tar \
            --create \
            --directory $CBL_TC \
            --file $tar_dst \
            --zstd \
            (realpath {$CBL_TC_BNTL_STORE,$CBL_TC_LLVM_STORE}-latest | string replace $CBL_TC/ '')
        printf '\nTarball is available at: %s\n' $tar_dst
    else
        print_error "Either binutils or LLVM is not built in $CBL_TC?"
        return 1
    end
end
