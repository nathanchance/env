#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function gen_sha256sum -d "Generate a .sha256 file for a file from the Internet"
    set url $argv[1]
    set file (path basename $url)

    crl -O $url; or return
    sha256sum $file >$file.sha256
    diskus $file
    rm -rf $file
    crl -O $url; or return
    sha256sum -c $file.sha256
    diskus $file
    rm -rf $file
end
