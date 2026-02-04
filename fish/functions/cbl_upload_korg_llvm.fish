#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_upload_korg_llvm -d "Upload kernel.org toolchain releases with kup"
    if test $PWD != $TMP_FOLDER/pgo-llvm-builder-staging
        __print_error "Not in $TMP_FOLDER/pgo-llvm-builder-staging?"
        return 1
    end

    set kup $SRC_FOLDER/kup/kup
    cbl_clone_repo (path basename $kup)

    if not test -e $HOME/.kuprc
        printf 'host = git@gitolite.kernel.org\nsubcmd = kup-server\n' >$HOME/.kuprc
    end

    for tar in *.tar
        if string match -qr -- '-[0-9a-f]{40}-' $tar
            set -a prerelease_tars $tar
        else if string match -qr -- -rust- $tar
            set -a rust_tars $tar
        else
            set -a release_tars $tar
        end

        rm -f $tar.asc

        gpg --detach-sign --armor $tar
        or return
    end

    if test -n "$release_tars"; and not test -f llvm-index.html
        __print_error 'No index.html generated for LLVM?'
        return 1
    end
    if test -n "$rust_tars"; and not test -f rust-index.html
        __print_error 'No index.html generated for Rust?'
        return 1
    end

    for tar in $release_tars
        $kup put $tar{,.asc} /pub/tools/llvm/files/$tar.gz
        or return

        set llvm_ver (string match -gr 'llvm-([0-9|.]+(?:-rc\d)?)' $tar)
        if test (string split . $llvm_ver | count) != 3
            __print_error "Malformed LLVM version found ('$llvm_ver')?"
            return 1
        end
        if not contains $llvm_ver $llvm_vers
            set -a llvm_vers $llvm_ver
        end
    end
    for tar in $rust_tars
        $kup put $tar{,.asc} /pub/tools/llvm/rust/files/$tar.gz
        or return
    end
    if test -n "$release_tars"
        $kup put llvm-index.html{,.asc} /pub/tools/llvm/index.html
        or return

        if test (count $llvm_vers) = 1
            cbl_gen_korg_llvm_announce $llvm_vers
        end
    end
    if test -n "$rust_tars"
        $kup put rust-index.html{,.asc} /pub/tools/llvm/rust/index.html
        or return
    end

    for tar in $prerelease_tars
        set remote_tar /pub/tools/llvm/files/prerelease/$tar.gz
        set link_tar (path dirname $remote_tar)/llvm-main-latest-(string split -f 2 -m 1 -r - $tar).gz

        $kup put $tar{,.asc} $remote_tar
        or return

        $kup rm $link_tar &>/dev/null
        $kup ln $remote_tar $link_tar &| string match -er 'FATAL: LINK of compressed file failed'
        and return
    end
    bell
end
