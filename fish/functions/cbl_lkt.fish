#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function cbl_lkt -d "Tests a Linux kernel with llvm-kernel-testing"
    in_container_msg -c; or return

    set i 1
    set argc (count $argv)
    while test $i -le $argc
        set arg $argv[$i]
        switch $arg
            ##########################
            # Arguments to 'main.py' #
            ##########################
            case -a --architectures -t --targets
                set -a main_py_args $arg
                set i (math $i + 1)
                while test $i -le $argc
                    set arg $argv[$i]
                    if string match -qr '^-' -- $arg
                        set i (math $i - 1)
                        break
                    end
                    set -a main_py_args $arg
                    set i (math $i + 1)
                end

            case -b --build-folder --boot-utils-folder
                set next (math $i + 1)
                set -a main_py_args $arg $argv[$next]
                set i $next

            case --binutils-prefix
                set next (math $i + 1)
                set binutils_prefix $argv[$next]
                set i $next

            case -l --linux-folder
                set next (math $i + 1)
                set linux_folder $argv[$next]
                set i $next

            case --llvm-prefix
                set next (math $i + 1)
                set llvm_prefix $argv[$next]
                set i $next

            case --qemu-prefix
                set next (math $i + 1)
                set qemu_prefix $argv[$next]
                set i $next

            case --save-objects --use-ccache
                set -a main_py_args $arg

            case --tc-prefix
                set next (math $i + 1)
                set tc_prefix $argv[$next]
                set i $next

                ##########################
                # Arguments to 'cbl_lkt' #
                ##########################
            case -s --system-binaries
                set system_binaries true

            case --tree
                set next (math $i + 1)
                set tree $argv[$next]
                set i $next

            case '*'
                print_error "Invalid argument: '$arg'"
                return 1
        end
        set i (math $i + 1)
    end

    if test -z "$linux_folder"
        if test -z "$tree"
            set tree linux-next
        end
        set linux_folder $CBL_BLD_P/$tree
    end

    # We assume that the dependencies are available in an image other than nathan/dev/arch
    if test "$system_binaries" != true
        if test -z "$llvm_prefix$binutils_prefix$tc_prefix"
            if test -e $CBL_TC_BNTL
                set binutils_prefix (dirname $CBL_TC_BNTL)
            end
            if test -e $CBL_TC_LLVM
                set llvm_prefix (dirname $CBL_TC_LLVM)
            end
        end
        if test -z "$qemu_prefix"; and test -e $CBL_QEMU
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

        set -a main_py_args --binutils-prefix $binutils_prefix
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

        set -a main_py_args --llvm-prefix $llvm_prefix
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

        set -a main_py_args --tc-prefix $tc_prefix
    end

    if test -n "$qemu_prefix"
        for qemu_binary in $qemu_prefix/bin/qemu-system-'*'
            true
        end

        if test -z "$qemu_binary"
            print_error "QEMU could not be found in $qemu_prefix/bin"
            return 1
        end

        set -a main_py_args --qemu-prefix $qemu_prefix
    end

    if not string match -qr -- --build-folder $main_py_args
        set -a main_py_args --build-folder $TMP_BUILD_FOLDER/(basename $linux_folder)
    end

    set log_folder $CBL/build-logs/(basename $linux_folder)-(date +%F-%T)
    mkdir -p $log_folder

    if is_github_actions
        set lkt $GITHUB_WORKSPACE/lkt
    else
        set lkt $CBL_LKT
        if not test -d $lkt
            mkdir -p (dirname $lkt)
            git clone https://github.com/nathanchance/llvm-kernel-testing $lkt
        end
        if not location_is_primary
            git -C $lkt urh
        end
    end

    set fish_trace 1
    $lkt/main.py \
        --linux-folder $linux_folder \
        --log-folder $log_folder \
        $main_py_args
    set lkt_ret $status
    set -e fish_trace

    if test $lkt_ret -ne 0
        if test $lkt_ret -eq 130
            rm -fr $log_folder
        else
            set msg "main.py failed in $linux_folder"
            print_error "$msg"
            tg_msg "$msg"
        end
        return $lkt_ret
    end

    # objtool | -Wframe-larger-than: Too many to deal with for now
    # override: CPU_BIG_ENDIAN changes choice state | override: LTO_CLANG_THIN changes choice state: Warnings from merge_config that are harmless in this context
    # *.log: Any warnings from this will be in the other logs
    # include/linux/bcache.h:3: https://github.com/ClangBuiltLinux/linux/issues/1065
    # llvm-objdump: error: 'vmlinux': not a dynamic object: https://github.com/ClangBuiltLinux/linux/issues/1427
    # unused during compilation: '-march=arm: https://github.com/ClangBuiltLinux/linux/issues/1315
    # scripts/(extract-cert|sign-file).c: OpenSSL deprecation warnings, we do not care: https://github.com/ClangBuiltLinux/linux/issues/1555
    # .note.GNU-stack, LOAD + RWX: New binutils warnings that are not clang specific: https://sourceware.org/bugzilla/show_bug.cgi?id=29072
    # error: write on a pipe with no reader: https://github.com/ClangBuiltLinux/linux/issues/1651
    # macro defined with named parameters / macro local_irq_enable reg=: https://github.com/ClangBuiltLinux/linux/issues/1415
    set blocklist_items \
        "objtool:" \
        Wframe-larger-than \
        "override: (CPU_BIG_ENDIAN|LTO_CLANG_THIN) changes choice state" \
        "info.log" \
        "success.log" \
        "failed.log" \
        "skipped.log" \
        "union jset::\(anonymous at ./usr/include/linux/bcache.h:" \
        "llvm-objdump: error: 'vmlinux': not a dynamic object" \
        "unused during compilation: '-march=arm" \
        "scripts/(extract-cert|sign-file).c:[0-9]+:[0-9]+: warning: '(ENGINE|ERR)_.*' is deprecated \[-Wdeprecated-declarations\]" \
        "missing .note.GNU-stack section implies executable stack" \
        "requires executable stack \(because the .note.GNU-stack section is executable\)" \
        "has a LOAD segment with RWX permissions" \
        "error: write on a pipe with no reader" \
        "(asmmacro.h|genex.S|[0-9]+):.*macro defined with named parameters" \
        "macro local_irq_enable reg="
    set blocklist (string join "|" $blocklist_items)
    set searchlist_items \
        "error:" \
        "ERROR:" \
        "FAILED:" \
        "FATAL:" \
        undefined \
        "Unsupported relocation type:" \
        "warning:" \
        "WARNING:"
    set searchlist (string join "|" $searchlist_items)

    for file_path in $log_folder $linux_folder $CBL_LKT/src/linux-clang-cfi
        set -a sed_args -e "s;$file_path/;;g"
    end

    set tmp_file (mktemp)
    rg "$searchlist" $log_folder/*.log &| rg -v -- "$blocklist" &| sed $sed_args &| sort &| uniq >$tmp_file

    set mail_log $log_folder/mail.log

    begin
        cat $log_folder/info.log
        if test -f $log_folder/failed.log
            echo
            echo "List of failed tests:"
            echo
            cat $log_folder/failed.log
        end

        if test -f $log_folder/skipped.log
            echo
            echo "List of skipped tests:"
            echo
            cat $log_folder/skipped.log
        end

        # Filter harder
        set unique_warnings "$(sed -e 's/^[^:]*://g' -e 's/^.*Section mismatch/Section mismatch/' $tmp_file &| sort &| uniq)"
        if test -n "$unique_warnings"
            echo
            echo "Unique warning report:"
            echo
            echo "$unique_warnings"
        end

        set filtered_warnings "$(cat $tmp_file)"
        if test -n "$filtered_warnings"
            echo
            echo "Filtered warning report:"
            echo
            echo "$filtered_warnings"
        end

        echo
        echo "List of successful tests:"
        echo
        cat $log_folder/success.log

        set full_warnings "$(rg "$searchlist" $log_folder/*.log &| sed $sed_args &| sort &| uniq)"
        if test -n "$full_warnings"
            echo
            echo "Full warning report:"
            echo
            echo "$full_warnings"
        end

        set mfc (git -C $linux_folder mfc)
        if test -n "$mfc"
            echo
            echo (basename $linux_folder)" commit log:"
            echo
            git -C $linux_folder l $mfc^^..HEAD
        end
    end >$mail_log

    rm $tmp_file

    mail_msg $mail_log

    echo "Full logs available at: $log_folder"
    echo

    rm $mail_log
end
