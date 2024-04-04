#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2023 Nathan Chancellor

function cbl_install_tc_tar -d "Install a toolchain tarball generated with create_cbl_tc_tar"
    if test (count $argv) -lt 1
        print_error "Provide toolchain tarball as argument!"
        return 1
    end
    set tar $argv[1]

    set tcs (tar -tf $tar | python3 -c "import re, sys
print('\n'.join({
    m[0]
    for m
    in re.findall('^((binutils|llvm)/[0-9A-Za-z-_]+)/',
                  sys.stdin.read(),
                  flags=re.M)
}))")
    mkdir -p $CBL_TC
    tar -C $CBL_TC -axf $tar
    for tc in $tcs
        cbl_upd_software_symlinks (dirname $tc) $CBL_TC/$tc
    end
end
