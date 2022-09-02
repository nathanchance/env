#
#/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

function oci_bld -d "Build an OCI container image"
    in_container_msg -h; or return

    if not command -q podman
        print_warning "oci_bld requires podman, skipping..."
        return 0
    end

    for arg in $argv
        switch $arg
            case compilers
                set -a images \
                    gcc-(seq 5 12) \
                    llvm-(seq 11 16) \
                    llvm-android

            case dev dev/{arch,debian,fedora,suse,ubuntu} lei {gcc,llvm}-'*' makepkg
                set -a images $arg
        end
    end

    for image in $images
        set -l podman_args

        switch $image
            case gcc-5
                set base ubuntu:xenial
            case gcc-'*' llvm-1{3,4,5,6}
                set base ubuntu:jammy
            case llvm-1{1,2}
                set base ubuntu:focal
            case llvm-android
                if test (uname -m) != x86_64
                    print_error "$image cannot be build on non-x86_64 hosts"
                    continue
                end
                set base ubuntu:jammy
        end

        switch $image
            case dev
                set folder (get_dev_img)
                set image $folder

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
