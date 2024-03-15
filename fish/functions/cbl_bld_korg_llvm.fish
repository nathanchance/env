#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_bld_korg_llvm
    in_container_msg -h
    or return

    # Just LLVM is required, Linux will be added if needed.
    set repos_to_update l

    for arg in $argv
        switch $arg
            case -t --test-linux
                set test_linux y
            case '*'
                set -a llvm_vers $arg
        end
    end
    if not set -q llvm_vers
        read -a -P 'LLVM versions: ' llvm_vers
    end
    if test (count $argv) -eq 0
        read -P 'Test Linux afterwards (y/n): ' test_linux
    end

    if test "$test_linux" = y
        set -a repos_to_update m s
    end

    begin
        header "Updating sources"

        cbl_upd_src_c $repos_to_update
        and if not test -d $CBL_TC_BLD
            git clone -b personal https://github.com/nathanchance/tc-build $CBL_TC_BLD
        end
        and if not is_location_primary
            git -C $CBL_TC_BLD urh
        end
    end
    or return

    mkdir -p $TMP_FOLDER
    set -g tmp_llvm_install (mktemp -d -p $TMP_FOLDER -t pgo-llvm-builder.XXXXXXXXXXXX)

    if not $PYTHON_FOLDER/pgo-llvm-builder/build.py \
            --build-folder (tbf pgo-llvm-builder) \
            --install-folder $tmp_llvm_install \
            --llvm-folder $CBL_SRC_C/llvm-project \
            --tc-build-folder $CBL_TC_BLD \
            --versions $llvm_vers
        tg_msg "pgo-llvm-builder failed on $(uname -n) @ $(date) with return code '$ret'!"
        return 1
    end

    if test "$test_linux" = y
        for tc in (fd -a -d 1 -t d . $tmp_llvm_install)
            for src in $CBL_SRC_C/linux $CBL_SRC_C/linux-stable-$CBL_STABLE_VERSIONS
                if dbx_has_82a69f0
                    dbxe -- fish -c "cbl_lkt --linux-folder $src --llvm-prefix $tc --no-timeout"
                else
                    dbxe -- "fish -c 'cbl_lkt --linux-folder $src --llvm-prefix $tc --no-timeout'"
                end
                or break
            end
            or break
        end
    end
end
