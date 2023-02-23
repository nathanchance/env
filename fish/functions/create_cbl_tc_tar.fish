#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function create_cbl_tc_tar -d "Create tarball with latest toolchains in $CBL_TC_STOW"
    if test -L $CBL_TC_STOW_BINUTILS-latest; and test -L $CBL_TC_STOW_LLVM-latest
        set tar_dst $CBL_TC_STOW/latest-cbl-tc.tar.zst
        tar \
            --create \
            --directory $CBL_TC_STOW \
            --file $tar_dst \
            --zstd \
            (realpath {$CBL_TC_STOW_BNTL,$CBL_TC_STOW_LLVM}-latest | string replace $CBL_TC_STOW/ '')
        printf '\nTarball is available at: %s\n' $tar_dst
    else
        print_error "Either binutils or LLVM is not built in $CBL_TC_STOW?"
        return 1
    end
end
