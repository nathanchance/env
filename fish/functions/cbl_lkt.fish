#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_lkt -d "Tests a Linux kernel with llvm-kernel-testing"
    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case --arches --boot-utils
                set next (math $i + 1)
                set -a test_sh_args $arg $argv[$next]
                set i $next

            case --defconfigs
                set -a test_sh_args $arg

            case -l --linux-src
                set next (math $i + 1)
                set linux_src $argv[$next]
                set i $next

            case --no-cfi
                set cfi false

            case -t --tc-prefix
                set next (math $i + 1)
                set tc_prefix $argv[$next]
                set i $next

            case --tree
                set next (math $i + 1)
                set tree $argv[$next]
                set i $next
        end
        set i (math $i + 1)
    end

    if test -z "$linux_src"
        if test -z "$tree"
            set tree linux-next
        end
        set linux_src $CBL_BLD_P/$tree
    end
    if test -z "$tc_prefix"
        set tc_prefix $CBL_USR
    end
    if test (basename $linux_src) = linux; and test "$cfi" != false
        set -a test_sh_args --test-cfi-kernel
    end

    if not test -d $tc_prefix/bin
        print_error "$tc_prefix value is wrong, no bin folder"
        return 1
    end

    for binary in $tc_prefix/bin/*
        switch (basename $binary)
            case as '*'-linux-gnu-as
                set as_found true
            case clang
                set clang_found true
        end
    end
    if test -z "$as_found"
        print_error "GNU as could not be found in $tc_prefix/bin"
        return 1
    end
    if test -z "$clang_found"
        print_error "clang could not be found in $tc_prefix/bin"
        return 1
    end

    set log_dir $CBL/build-logs/(basename $linux_src)-(date +%F-%T)
    mkdir -p $log_dir

    set lkt $CBL/llvm-kernel-testing
    if not test -d $lkt
        mkdir -p (dirname $lkt)
        git clone https://github.com/nathanchance/llvm-kernel-testing $lkt
    end
    git -C $lkt pull -qr

    set fish_trace 1
    PATH="$CBL_QEMU_BIN:$PATH" $CBL/llvm-kernel-testing/test.sh \
        --linux-src $linux_src \
        --log-dir $log_dir \
        --skip-tc-build \
        --tc-prefix $tc_prefix \
        $test_sh_args; or return
    set -e fish_trace

    # arch/powerpc/boot/inffast.c: A warning we do not really care about (https://github.com/ClangBuiltLinux/linux/issues/664)
    # objtool: Too many to deal with for now
    # override: CPU_BIG_ENDIAN changes choice state | override: LTO_CLANG_THIN changes choice state: Warnings from merge_config that are harmless in this context
    # results.log: Any warnings from this will be in the other logs
    # include/linux/bcache.h:3: https://github.com/ClangBuiltLinux/linux/issues/1065
    # llvm-objdump: error: 'vmlinux': not a dynamic object: https://github.com/ClangBuiltLinux/linux/issues/1427
    # warningng: argument unused during compilation: '-march=arm: https://github.com/ClangBuiltLinux/linux/issues/1315
    set blocklist "arch/powerpc/boot/inffast.c|objtool:|override: CPU_BIG_ENDIAN changes choice state|override: LTO_CLANG_THIN changes choice state|results.log|union jset::\(anonymous at ./usr/include/linux/bcache.h:|llvm-objdump: error: 'vmlinux': not a dynamic object|warning: argument unused during compilation: '-march=arm"
    set searchlist "error:|FATAL:|undefined|Unsupported relocation type:|warning:|WARNING:"

    for file_path in $log_dir $linux_src $CBL/llvm-kernel-testing/src/linux-clang-cfi
        set -a sed_args -e "s;$file_path/;;g"
    end

    set tmp_file (mktemp)
    rg "$searchlist" $log_dir/*.log &| rg -v -- "$blocklist" &| sed $sed_args &| sort &| uniq >$tmp_file

    set haste_log $log_dir/haste.log

    begin
        echo "Host: "(uname -n)
        echo
        cat $log_dir/results.log

        # Filter harder
        set unique_warnings (sed -e 's/^[^:]*://g' -e 's/^.*Section mismatch/Section mismatch/' $tmp_file &| sort &| uniq &| string collect)
        if test -n "$unique_warnings"
            echo
            echo "Unique warning report:"
            echo "$unique_warnings"
        end

        set full_warnings (cat $tmp_file | string collect)
        if test -n "$full_warnings"
            echo
            echo "Full warning report:"
            echo "$full_warnings"
        end

        set mfc (git -C $linux_src mfc)
        if test -n "$mfc"
            echo
            echo (basename $linux_src)" commit log:"
            echo
            git -C $linux_src lo $mfc^^..HEAD
        end
    end >$haste_log

    rm $tmp_file

    set message (basename $log_dir)" build results: "(haste $haste_log)

    tg_msg "$message"

    echo
    echo "$message"
    echo "Full logs available at: $log_dir"
    echo

    rm $haste_log
end
