#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function cbl_bld_llvm_korg -d "Build (and optionally test) LLVM for kernel.org"
    __in_container_msg -h
    or return

    # Just LLVM is required, Linux will be added if needed.
    set repos_to_update l

    for arg in $argv
        switch $arg
            case -b --build-env
                set build_env y
            case -r --reset
                set reset y
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

    if test "$reset" = y
        for old_dir in $TMP_FOLDER/pgo-llvm-builder.*
            rm -fr $old_dir
        end
    end

    if test "$build_env" = y
        echo 'Requesting sudo for mkosi...'
        sudo true
        or return

        set mach_dir /var/lib/machines/pgo-llvm-builder
        if sudo test -e $mach_dir
            sudo rm -r $mach_dir
            or return
        end

        mkosi_bld $PYTHON_FOLDER/(path basename $mach_dir)
        or return
    end

    begin
        header "Updating sources"

        cbl_upd_src c $repos_to_update
        and cbl_clone_repo $CBL_TC_BLD
        and if not __is_location_primary
            git -C $CBL_TC_BLD urh
        end
    end
    or return

    mkdir -p $TMP_FOLDER
    set -g tmp_llvm_install (mktemp -d -p $TMP_FOLDER -t pgo-llvm-builder.XXXXXXXXXXXX)

    if not set -q llvm_bld
        set llvm_bld (tbf pgo-llvm-builder)
    end

    if not $PYTHON_FOLDER/pgo-llvm-builder/build.py \
            --build-folder $llvm_bld \
            --install-folder $tmp_llvm_install \
            --llvm-folder $CBL_SRC_C/llvm-project \
            --tc-build-folder $CBL_TC_BLD \
            --versions $llvm_vers
        __tg_msg "pgo-llvm-builder failed!"
        return 1
    end
    bell

    if test "$test_linux" = y
        for tc in (fd -a -d 1 -t d . $tmp_llvm_install)
            for src in $CBL_SRC_C/linux $CBL_SRC_C/linux-stable-$CBL_STABLE_VERSIONS
                sd_nspawn -r 'cbl_lkt --linux-folder '(nspawn_path -c $src)' --llvm-prefix '(nspawn_path -c $tc)
                or break
            end
            or break
        end
    end
end
