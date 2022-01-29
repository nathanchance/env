#
#/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function boci -d "Build an OCI container image"
    in_container_msg -h; or return

    if not command -q podman
        print_warning "boci requires podman, skipping..."
        return 0
    end

    for arg in $argv
        switch $arg
            case compilers
                set -a images \
                    gcc-{5,6,7,8,9,10,11} \
                    llvm-{10,11,12,13,14,android}

            case dev dev/{arch,fedora,suse,ubuntu} lei {gcc,llvm}-'*' makepkg
                set -a images $arg
        end
    end

    for image in $images
        set -l podman_args

        switch $image
            case gcc-5
                set base ubuntu:xenial
            case gcc-6
                set base debian:stretch
            case gcc-7
                set base ubuntu:bionic
            case gcc-8
                set base debian:buster
            case gcc-9
                set base ubuntu:focal
            case gcc-10
                set base debian:bullseye
            case gcc-11
                set base ubuntu:impish
            case llvm-10
                set base ubuntu:groovy
            case llvm-11
                set base debian:bookworm
            case llvm-12 llvm-13 llvm-14
                set base ubuntu:impish
            case llvm-android
                if test (uname -m) != x86_64
                    print_error "$image cannot be build on non-x86_64 hosts"
                    continue
                end
                set base ubuntu:impish
        end

        switch $image
            case dev
                switch (uname -m)
                    case x86_64
                        set folder dev/arch
                        set image dev/arch
                    case '*'
                        set folder dev/fedora
                        set image dev/fedora
                end

            case {gcc,llvm}-'*'
                set podman_args \
                    --build-arg BASE=docker.io/$base \
                    --build-arg COMPILER=$image
                set folder compiler

            case '*'
                set folder $image
        end

        pushd $ENV_FOLDER/podman/$folder; or return

        set fish_trace 1
        podman build \
            $podman_args \
            --layers=false \
            --pull \
            --tag $GHCR/$image .; or return
        set -e fish_trace

        popd; or return
    end
end
