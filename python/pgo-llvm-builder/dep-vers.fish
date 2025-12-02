#!/usr/bin/env fish

function get_current_release
    set -l binary $argv[1]
    set -l file $PYTHON_FOLDER/pgo-llvm-builder/mkosi.postinst.d/*-modern-$binary.*.chroot
    if test -z "$file"
        __print_error "Could not find $binary file in $PYTHON_FOLDER/pgo-llvm-builder"
        exit 128
    end

    if not set -l current_ver (string match -gr 'version(?: |=)([0-9|.]+)$' <$file)
        __print_error "Could not find version in $file"
        exit 128
    end

    printf '%8s%8s | ' $binary: $current_ver
end

function get_latest_release
    set -l url
    set -l refspec

    for arg in $argv
        switch $arg
            case https://'*'
                set url $arg
            case refs/tags/'*'
                set refspec $arg
        end
    end
    if test -z "$url"
        __print_error "No URL provided?"
        exit 128
    end
    if test -z "$refspec"
        set refspec refs/tags/v'*'
    end

    set -l latest_ver 0
    git ls-remote --refs $url $refspec | string match -gr 'refs/tags/v?([0-9|.]+)$' | while read -l current_ver
        if test (vercmp $current_ver $latest_ver) -gt 0
            set latest_ver $current_ver
        end
    end
    printf '%s\n' $latest_ver
end

printf '%16s | latest\n' current

get_current_release cmake
get_latest_release https://github.com/Kitware/CMake

get_current_release fish
get_latest_release https://github.com/fish-shell/fish-shell refs/tags/'*'

get_current_release ninja
get_latest_release https://github.com/ninja-build/ninja

get_current_release python
get_latest_release https://github.com/python/cpython

get_current_release zstd
get_latest_release https://github.com/facebook/zstd
