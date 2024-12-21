#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2024 Nathan Chancellor

function mkosi_bld -d "Build a distribution using mkosi"
    # Normally, we should just be able to use mkosi from our distribution
    # but we require some newer fixes and features at the moment
    if not in_venv
        if not test -e $PY_VENV_DIR/mkosi
            py_venv c mkosi
        end

        py_venv e mkosi
        or return

        if not command -q mkosi
            pip install --upgrade pip

            pip install git+https://github.com/systemd/mkosi
            or return
        end
    else if test (basename $VIRTUAL_ENV) != mkosi
        print_error "Already in a virtual environment?"
        return 1
    end

    if test (count $argv) -eq 0
        set image (dev_img)
    else
        set image $argv[1]
    end

    set directory $ENV_FOLDER/mkosi/$image
    if not test -e $directory/mkosi.conf
        print_error "No build files for $image?"
        return 1
    end

    set build_sources \
        # We may need to use custom functions from our Python framework
        $PYTHON_FOLDER:/python \
        # We may need to look at the configuration of the host
        /etc:/etc

    sudo (command -v mkosi) \
        --build-sources (string join , $build_sources) \
        --directory $directory \
        --force
end
