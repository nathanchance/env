#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function podcmd -d "A wrapper for 'podrun <img> fish -c'"
    set i 1
    while test $i -le (count $argv)
        set arg $argv[$i]
        switch $arg
            case -a --add-path
                if test "$seen_cmd" = true
                    set -a fish_cmd $arg
                else
                    set add_path true
                end

            case -d --debug
                if test "$seen_cmd" = true
                    set -a fish_cmd $arg
                else
                    set debug true
                end

            case -l --llvm
                if test "$seen_cmd" = true
                    set -a fish_cmd $arg
                else
                    set llvm true
                end

            case -s --skip-path
                if test "$seen_cmd" = true
                    set -a fish_cmd $arg
                else
                    set skip_path true
                end

            case -e -v
                set next (math $i + 1)
                set -a podman_args $arg $argv[$next]
                set i $next

            case --cap-drop='*' --env='*' --volume='*'
                set -a podman_args $arg

            case nathan/'*' $GHCR/'*'
                set img $arg

            case '*'/build-llvm.py build-llvm.py
                set llvm true
                set -a fish_cmd $arg
                set seen_cmd true

            case kmake make '*'/build.fish '*'/gen_wsl_config.fish
                set make true
                set -a fish_cmd $arg
                set seen_cmd true

            case kboot qemu-'*'
                set qemu true
                set -a fish_cmd $arg
                set seen_cmd true

            case '*'
                set -a fish_cmd $arg
                set seen_cmd true
        end
        set i (math $i + 1)
    end

    # Default image
    if not set -q img
        switch (uname -m)
            case x86_64
                set img $GHCR/dev/arch
            case '*'
                set img $GHCR/dev/fedora
        end
    end

    # If we are using a development image, we default mount some paths
    if string match -qr nathan/dev/ "$img"; or string match -qr $GHCR/dev/ "$img"
        set dev_img true
    end
    if test "$dev_img" = true; and test "$skip_path" != true
        if test "$make" = true; or test "$add_path" = true
            if test -d $CBL_TC_BNTL
                set -a podman_args --volume=(dirname $CBL_TC_BNTL):/binutils
            end
            if test -d $CBL_TC_LLVM
                set -a podman_args --volume=(dirname $CBL_TC_LLVM):/llvm
            end
        end
        if test "$qemu" = true; or test "$add_path" = true
            if test -d $CBL_QEMU
                set -a podman_args --volume=$CBL_QEMU:/qemu
            end
        end
    end

    # If we are building LLVM, we need to drop CAP_DAC_OVERRIDE, otherwise
    # the lld tests will fail.
    if test "$llvm" = true
        set -a podman_args \
            --cap-drop=CAP_DAC_OVERRIDE
    end

    if test "$debug" = true
        set fish_trace 1
    end

    # Run command in container image
    podrun $podman_args $img fish -c "$fish_cmd"
end
