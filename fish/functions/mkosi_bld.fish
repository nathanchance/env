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

    if string match -qr ^/ $image
        set directory $image
    else
        set directory $ENV_FOLDER/mkosi/$image
    end
    if not test -e $directory/mkosi.conf
        print_error "No build files for $image?"
        return 1
    end

    # If mkosi is major version 25 or greater, we can use it directly.
    # If it is not, we use a virtual environment for simple access.
    # pgo-llvm-builder requires a patched mkosi, so require the venv
    # for that.
    if command -q mkosi; and test (mkosi --version | string match -gr '^mkosi ([0-9]+)') -ge 25; and not test (path basename $directory) = pgo-llvm-builder
    else if not in_venv
        set venv_dir $PY_VENV_DIR/mkosi
        if not test -e $venv_dir
            py_venv c mkosi
        end

        py_venv e mkosi
        or return

        if not command -q mkosi
            pip install --upgrade pip

            pip install git+https://github.com/systemd/mkosi
            or return

            crl https://github.com/nathanchance/patches/raw/refs/heads/main/mkosi/buster-security.patch | patch -d $venv_dir/lib/python*/site-packages -N -p1
        end
    else if test (path basename $VIRTUAL_ENV) != mkosi
        print_error "Already in a virtual environment?"
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
        case dev-arch
            set cache_dir pacman
        case dev-debian pgo-llvm-builder
            set cache_dir apt
        case dev-fedora
            set cache_dir dnf
    end

    sudo (command -v mkosi) \
        --build-sources (string join , $build_sources) \
        --directory $directory \
        --force \
        --package-cache-dir $mkosi_cache/$cache_dir \
        $mkosi_args
end
