#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function mkosi_bld -d "Build a distribution using mkosi"
    if test (count $argv) -eq 0
        set image $DEV_IMG
    else
        set image $argv[1]
        set mkosi_args $argv[2..]
    end

    if string match -qr ^dev- $image
        set distro (string split -f 2 - $image)
        if not string match -qr -- --distribution $mkosi_args
            set -a mkosi_args --distribution $distro
        end
        set image dev
    end

    set env_mkosi $ENV_FOLDER/mkosi
    if string match -qr ^/ $image
        set directory $image
    else
        set directory $env_mkosi/$image
    end
    set mkosi_conf $directory/mkosi.conf
    if not test -e $mkosi_conf
        __print_error "No build files for $image?"
        return 1
    end

    # If mkosi is major version 25 or greater, we can use it directly.
    # If it is not, we use a virtual environment for simple access.
    # pgo-llvm-builder requires a patched mkosi, so require the venv
    # for that.
    if command -q mkosi; and test (mkosi --version | string match -gr '^mkosi ([0-9]+)') -ge 25; and not test (path basename $directory) = pgo-llvm-builder
    else if not __in_venv
        set venv_args e u
        if not test -e $PY_VENV_DIR/mkosi
            set -p venv_args c
        end
        py_venv $venv_args mkosi
        or return
    else if test (path basename $VIRTUAL_ENV) != mkosi
        __print_error "Already in a virtual environment?"
        return 1
    end

    set build_sources \
        # We may need to use custom functions from our Python framework
        $PYTHON_FOLDER:/python \
        # We may need to look at the configuration of the host
        /etc:/etc

    set mkosi_cache $XDG_FOLDER/cache/mkosi
    if not test -d $mkosi_cache
        mkdir -p $mkosi_cache
    end

    switch (path basename $directory)
        case dev
            switch $distro
                case arch
                    set cache_dir pacman
                case debian
                    set cache_dir apt
                case fedora
                    set cache_dir dnf
            end
        case '*'arch'*'
            set cache_dir pacman
        case '*'debian'*'
            set cache_dir apt
        case pgo-llvm-builder
            set cache_dir apt
            set -a mkosi_args --environment PYTHON_PGO_BUILDER_UID=(id -u)
        case '*'fedora'*'
            set cache_dir dnf
        case '*'
            set cache_dir generic
    end

    set mkosi (command -v mkosi)

    request_root "Running mkosi"
    or return

    set tools_tree $env_mkosi/tools
    if not test -e $tools_tree/etc/resolv.conf
        run0 $mkosi \
            --directory (path dirname $mkosi)/../lib/python*/site-packages/mkosi/resources/mkosi-tools \
            --format directory \
            --output (path basename $tools_tree) \
            --output-directory (path dirname $tools_tree) \
            --profile misc,package-manager,runtime
        or return

        run0 chown -R $USER:$USER $tools_tree
        or return
    end

    if contains -- bootable $mkosi_args
        set bootable true
    end

    set mkosi_cmd \
        $mkosi \
        --build-sources (string join , $build_sources) \
        --directory $directory \
        --force \
        --package-cache-dir $mkosi_cache/$cache_dir \
        --tools-tree $tools_tree \
        $mkosi_args

    if not set image_id ($mkosi_cmd summary --json | python3 -c "import json, sys
mkosi_json = json.load(sys.stdin)
for image in mkosi_json['Images']:
    if image['Image'] == 'main':
        image_id = image['ImageId']
        break
else:
    raise RuntimeError('No main image?')
print(image_id)")
        __print_error "Cannot get image ID from 'mkosi summary'?"
        return 1
    end

    # If we are using a bootable image, output to $VM_FOLDER/mkosi/<image_id> by default
    if set -q bootable; and not contains -- --output-directory $mkosi_args
        set bootable_output $VM_FOLDER/mkosi/$image_id
        mkdir -p (path dirname $bootable_output)
        set -a mkosi_cmd --output-directory $bootable_output
    end

    run0 $mkosi_cmd
    or return

    if set -q bootable_output
        run0 chown -R $USER:$USER $bootable_output
    end

    # selinux contexts may get messed up, fix them if necessary
    if test -e /sys/fs/selinux; and test (cat /sys/fs/selinux/enforce) = 1; and not set -q bootable
        set machine_dir /var/lib/machines/$image_id
        __tg_msg "root authorization needed to check SELinux context of $machine_dir"
        set context (run0 stat $machine_dir | string match -gr '^Context: (.*)$')
        if test "$context" != "system_u:object_r:unlabeled_t:s0"; and test "$context" != "system_u:object_r:systemd_machined_var_lib_t:s0"
            __print_warning "$machine_dir context is unexpected ('$context'), running restorcecon..."
            run0 restorecon -R $machine_dir
        end
    end
end
