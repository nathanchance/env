#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_lkt -d "Tests a Linux kernel with llvm-kernel-testing"
    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case --arches --boot-utils
                set next (math $i + 1)
                set -a test_sh_args $arg $argv[$next]
                set i $next

            case --binutils-prefix
                set next (math $i + 1)
                set binutils_prefix $argv[$next]
                set i $next

            case --cfi
                set cfi true

            case --defconfigs --no-ccache
                set -a test_sh_args $arg

            case -i --image
                set next (math $i + 1)
                set podman_image $argv[$next]
                set i $next

            case -l --linux-src
                set next (math $i + 1)
                set linux_src $argv[$next]
                set i $next

            case --llvm-prefix
                set next (math $i + 1)
                set llvm_prefix $argv[$next]
                set i $next

            case --no-cfi
                set cfi false

            case -q --qemu-prefix
                set next (math $i + 1)
                set qemu_prefix $argv[$next]
                set i $next

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
    if test -z "$cfi"
        set cfi false
    end
    if test (basename $linux_src) = linux; and test "$cfi" != false
        set -a test_sh_args --test-cfi-kernel
    end

    # We assume that the dependencies are available in an image other than nathan/dev/arch
    if test -z "$podman_image"
        if test -z "$llvm_prefix$binutils_prefix$tc_prefix"
            set tc_prefix $CBL_TC
        end
        if test -z "$qemu_prefix"
            set qemu_prefix $CBL_QEMU
        end
    end

    if test -n "$binutils_prefix"
        if not test -d $binutils_prefix/bin
            print_error "$binutils_prefix value is wrong, no bin folder"
            return 1
        end

        set -l as_found false
        for binutils_binary in $binutils_prefix/bin/*
            switch (basename $binutils_binary)
                case as '*'-linux-gnu'*'-as
                    set as_found true
            end
        end

        if test "$as_found" != true
            print_error "GNU as could not be found in $binutils_prefix/bin"
            return 1
        end

        set -a test_sh_args --binutils-prefix $binutils_prefix
    end

    if test -n "$llvm_prefix"
        if not test -d $llvm_prefix/bin
            print_error "$llvm_prefix value is wrong, no bin folder"
            return 1
        end

        for clang_binary in $llvm_prefix/bin/clang*
            true
        end

        if test -z "$clang_binary"
            print_error "clang could not be found in $tc_prefix/bin"
            return 1
        end

        set -a test_sh_args --llvm-prefix $llvm_prefix
    end

    if test -n "$tc_prefix"
        if not test -d $tc_prefix/bin
            print_error "$tc_prefix value is wrong, no bin folder"
            return 1
        end

        set -l as_found false
        set -l clang_found false
        for tc_binary in $tc_prefix/bin/*
            switch (basename $tc_binary)
                case as '*'-linux-gnu'*'-as
                    set as_found true
                case clang
                    set clang_found true
            end
        end

        if test "$as_found" != true
            print_error "GNU as could not be found in $tc_prefix/bin"
            return 1
        end

        if test "$clang_found" != true
            print_error "clang could not be found in $tc_prefix/bin"
            return 1
        end

        set -a test_sh_args --tc-prefix $tc_prefix
    end

    if test -n "$qemu_prefix"
        for qemu_binary in $qemu_prefix/bin/qemu-system-'*'
            true
        end

        if test -z "$qemu_binary"
            print_error "QEMU could not be found in $qemu_prefix/bin"
            return 1
        end

        set -a test_sh_args --qemu-prefix $qemu_prefix
    end

    set log_dir $CBL/build-logs/(basename $linux_src)-(date +%F-%T)
    mkdir -p $log_dir

    if not test -d $CBL_LKT
        mkdir -p (dirname $CBL_LKT)
        git clone https://github.com/nathanchance/llvm-kernel-testing $CBL_LKT
    end
    git -C $CBL_LKT pull -qr

    set fish_trace 1
    podcmd $podman_image $CBL_LKT/test.sh \
        --linux-src $linux_src \
        --log-dir $log_dir \
        $test_sh_args; or return
    set -e fish_trace

    # objtool: Too many to deal with for now
    # override: CPU_BIG_ENDIAN changes choice state | override: LTO_CLANG_THIN changes choice state: Warnings from merge_config that are harmless in this context
    # results.log: Any warnings from this will be in the other logs
    # include/linux/bcache.h:3: https://github.com/ClangBuiltLinux/linux/issues/1065
    # llvm-objdump: error: 'vmlinux': not a dynamic object: https://github.com/ClangBuiltLinux/linux/issues/1427
    # warning: argument unused during compilation: '-march=arm: https://github.com/ClangBuiltLinux/linux/issues/1315
    # scripts/(extract-cert|sign-file).c: OpenSSL deprecation warnings, we do not care: https://github.com/ClangBuiltLinux/linux/issues/1555
    set blocklist "objtool:|override: (CPU_BIG_ENDIAN|LTO_CLANG_THIN) changes choice state|results.log|union jset::\(anonymous at ./usr/include/linux/bcache.h:|llvm-objdump: error: 'vmlinux': not a dynamic object|warning: argument unused during compilation: '-march=arm|scripts/(extract-cert|sign-file).c:[0-9]+:[0-9]+: warning: '(ENGINE|ERR)_.*' is deprecated \[-Wdeprecated-declarations\]"
    set searchlist "error:|FATAL:|undefined|Unsupported relocation type:|warning:|WARNING:"

    for file_path in $log_dir $linux_src $CBL_LKT/src/linux-clang-cfi
        set -a sed_args -e "s;$file_path/;;g"
    end

    set tmp_file (mktemp)
    rg "$searchlist" $log_dir/*.log &| rg -v -- "$blocklist" &| sed $sed_args &| sort &| uniq >$tmp_file

    set mail_log $log_dir/mail.log

    begin
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
    end >$mail_log

    rm $tmp_file

    mail_msg $mail_log

    echo "Full logs available at: $log_dir"
    echo

    rm $mail_log
end
