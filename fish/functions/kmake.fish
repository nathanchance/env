#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function kmake -d "Run make with all cores and adjust PATH temporarily"
    # Ensure that all PATH modifications are local to this function (like a subshell)
    set -lx PATH $PATH

    # Parse arguments
    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case 'NO_CCACHE=*'
                set (string split -f1 = $arg) (string split -f2 = $arg)

            case '*=*'
                if string match -q -r 'CC=' $arg
                    set cc_was_in_args true
                else
                    set -a make_args $arg
                end
                set (string split -f1 = $arg) (string split -f2 = $arg)

            case '*/' '*.i' '*.ko' '*.o' '*.s' all bindeb-pkg '*clean' '*config' '*docs' dtbs '*_install' '*Image*' kselftest modules mrproper '*_prepare' vmlinux
                set -a make_args $arg

            case -C
                set next (math $i + 1)
                set -a make_args $arg $argv[$next]
                set i $next

            case +s
                set silent false
        end
        set i (math $i + 1)
    end

    # Default values
    if not set -q cc_was_in_args
        set cc_was_in_args false
    end
    if not set -q FORCE_LE
        set FORCE_LE true
    end
    if not set -q silent
        set silent true
    end

    # Setup paths
    if test "$LLVM" = 1; or string match -q -- "*clang" "$CC"
        if set -q CBL_BIN; and test -d "$CBL_BIN"
            set -p PATH $CBL_BIN
        end
        if not set -q CC
            set CC clang
        end
    else
        if set -q GCC_TC_FOLDER
            set -p PATH $GCC_TC_FOLDER/11.2.0/bin
        end
        if not set -q CC
            set CC "$CROSS_COMPILE"gcc
        end
    end

    if set -q PO
        set -p PATH $PO
    end

    # Check that CC exists
    set CC (string split " " $CC)
    set cc_path (command -v $CC[-1])
    if not test -x "$cc_path"
        print_error "$CC[-1] could not be found or it is not executable!"
        return
    end

    # Print information about CC
    set cc_location (dirname $cc_path)
    printf '\n\e[01;32mCompiler location:\e[0m %s\n\n' $cc_location
    printf '\e[01;32mCompiler version:\e[0m %s \n\n' (eval $cc_path --version | head -1)

    # Print information about binutils if necessary
    if test "$LLVM_IAS" != 1
        set as_path (command -v "$CROSS_COMPILE"as)
        if not test -x $as_path
            print_error "binutils could not be found or they are not executable!"
            return
        end
        set as_location (dirname $as_path)
        if test "$as_location" != "$cc_location"
            printf '\e[01;32mBinutils location:\e[0m %s\n\n' $as_location
        end
        printf '\e[01;32mBinutils version:\e[0m %s \n\n' (eval $as_path --version | head -1)
    end

    # Set silent flag
    if test "$V" = 1; or test "$V" = 2
        set silent false
    end
    if test "$silent" = true
        set silent_make_flag s
    end

    if test "$FORCE_LE" = true; and test -z "$KCONFIG_ALLCONFIG"
        switch $ARCH
            case arm arm64
                if contains allmodconfig $make_args; or contains allyesconfig $make_args
                    set KCONFIG_ALLCONFIG /tmp/force-le.config
                    echo CONFIG_CPU_BIG_ENDIAN=n >$KCONFIG_ALLCONFIG
                    set -a make_args KCONFIG_ALLCONFIG=$KCONFIG_ALLCONFIG
                end
        end
    end

    if command -q ccache; and test -z "$NO_CCACHE"
        set -p make_args CC="ccache $CC"
    else
        if test "$cc_was_in_args" = true
            set -p make_args CC="$CC"
        end
    end

    # make might be an alias, we want that actual binary
    set make_binary (command -v make)

    set fish_trace 1
    time $make_binary -"$silent_make_flag"kj(nproc) $make_args
end
