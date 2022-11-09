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
                    gcc-$GCC_VERSIONS_KERNEL \
                    llvm-$LLVM_VERSIONS_KERNEL \
                    llvm-android

            case dev dev/{arch,debian,fedora,suse,ubuntu} {gcc,llvm}-'*'
                set -a images $arg
        end
    end

    for image in $images
        set -l podman_args

        switch $image
            case gcc-5
                set base ubuntu:xenial
            case llvm-12 llvm-11
                set base ubuntu:focal
            case llvm-android
                if test (uname -m) != x86_64
                    print_error "$image cannot be build on non-x86_64 hosts"
                    continue
                end
                set base ubuntu:jammy
            case gcc-'*' llvm-'*'
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

        set podman_build_cmd \
            podman build \
            $podman_args \
            --layers=false \
            --pull \
            --tag $GHCR/$image .
        print_cmd $podman_build_cmd
        $podman_build_cmd; or return

        popd; or return
    end
end
