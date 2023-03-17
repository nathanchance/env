#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function cbl_install_stable_llvm -d "Download and unpack my LLVM toolchains from kernel.org"
    for llvm_version in (get_latest_stable_llvm_version $LLVM_VERSIONS_KERNEL)
        set dst $CBL_TC_LLVM_STORE/$llvm_version
        if test -d $dst
            print_green "LLVM $llvm_version is already installed, skipping..."
            continue
        end

        mkdir -p $dst

        set local_tarball $NAS_FOLDER/Toolchains/llvm-$llvm_version-(uname -m).tar.zst
        if test -e $local_tarball
            tar -C $dst --strip-components=1 -axvf $local_tarball
        else
            crl https://kernel.org/pub/linux/kernel/people/nathan/llvm/(string replace zst xz (basename $local_tarball)) | tar -C $dst --strip-components=1 -xJvf -
        end; or return
    end
end
