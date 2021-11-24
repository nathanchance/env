#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function podrun -d "Runs 'podman run' with arguments to facilitate building in containers"
    if not command -q podman
        print_error "podrun requires podman to be installed"
        return 1
    end

    for arg in $argv
        switch $arg
            case --no-cap-drop
                set cap_drop false
            case '*'
                set -a args $arg
        end
    end

    # Ensures that permissions works for LLVM test suite (since container is
    # technically root). This can cause issues when using container
    # interactively so it can be dropped.
    if test "$cap_drop" != false
        set -a podman_args \
            --cap-drop CAP_DAC_OVERRIDE
    end

    # Allows KVM to be used inside the container
    # https://www.redhat.com/sysadmin/files-devices-podman
    if test -c /dev/kvm
        set -a podman_args \
            --device /dev/kvm \
            --group-add keep-groups
    end

    # Allows ccache to work across containers
    set -a podman_args \
        --env="CCACHE_DIR=$HOME/.cache/ccache" \
        --env="CCACHE_COMPRESS=true" \
        --env="CCACHE_COMPRESSLEVEL=19" \
        --env="CCACHE_MAXSIZE=$CCACHE_MAXSIZE"

    # Pass through HOME so that it does not become /home/root
    set -a podman_args \
        --env="HOME=$HOME"

    # Override Kbuild's user name and host, which will be root and some hash
    # respectively in the container.
    set -a podman_args \
        --env="KBUILD_BUILD_USER=$USER" \
        --env="KBUILD_BUILD_HOST=$hostname"

    # Passthrough LOCATION and SSH_CONNECTION from host for env scripts.
    set -a podman_args \
        --env="LOCATION=$LOCATION" \
        --env="SSH_CONNECTION=$SSH_CONNECTION"

    # Only set interactive flag if this is being run in an interactive shell
    if status is-interactive
        set -a podman_args \
            --interactive
    end

    # Allow an unlimited number of process IDs inside the container (helps full LTO)
    set -a podman_args \
        --pids-limit=-1

    # Remove container and allocate a TTY (standard podman flags)
    set -a podman_args \
        --rm \
        --tty

    # Mount in home directory for access to files
    set -a podman_args \
        --volume=$HOME:$HOME

    # If the main folder that holds my files is not the same as the home
    # folder, mount that in too
    if not string match -qr "$HOME" "$MAIN_FOLDER"
        set -a podman_args \
            --volume=$MAIN_FOLDER:$MAIN_FOLDER
    end

    # If a certain working directory was requested, use that; otherwise, use
    # the current working directory.
    if test -n "$WORKDIR"
        set -a podman_args \
            --workdir=$WORKDIR
    else
        set -a podman_args \
            --workdir=$PWD
    end

    set fish_trace 1
    podman run $podman_args $args
end
