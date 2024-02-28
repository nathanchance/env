#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_upload_korg_llvm -d "Upload kernel.org toolchain releases with kup"
    if test $PWD != $TMP_FOLDER/pgo-llvm-builder-staging
        print_error "Not in $TMP_FOLDER/pgo-llvm-builder-staging?"
        return 1
    end

    set kup_src $SRC_FOLDER/kup
    set kup $kup_src/kup

    if not test -e $kup
        mkdir -p (dirname $kup_src)
        git clone https://git.kernel.org/pub/scm/utils/kup/kup.git $kup_src
        or return
    end

    for tar in *.tar
        if string match -qr -- '-[0-9a-f]{40}-' $tar
            set -a prerelease_tars $tar
        else
            set -a release_tars $tar
        end

        rm -f $tar.asc

        gpg --detach-sign --armor $tar
        or return
    end

    if test -n "$release_tars"; and not test -f index.html
        print_error 'No index.html generated?'
        return 1
    end

    for tar in $release_tars
        $kup put $tar $tar.asc /pub/tools/llvm/files/$tar.gz
        or return
    end
    if test -n "$release_tars"
        $kup put index.html{,.asc} /pub/tools/llvm/index.html
        or return
    end

    for tar in $prerelease_tars
        $kup put $tar $tar.asc /pub/tools/llvm/files/prerelease/$tar.gz
        or return

        set -l target_arch (string split -f 2 -m 1 -r - $tar)
        $kup ln /pub/tools/llvm/files/prerelease/{$tar,llvm-main-latest-$target_arch.tar}.gz
        or return
    end
end
