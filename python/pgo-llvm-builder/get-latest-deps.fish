#!/usr/bin/env fish

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
        return 128
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
    echo $latest_ver
end

printf 'cmake:  %s\n' (get_latest_release https://github.com/Kitware/CMake)
printf 'fish:   %s\n' (get_latest_release https://github.com/fish-shell/fish-shell refs/tags/'*')
printf 'ninja:  %s\n' (get_latest_release https://github.com/ninja-build/ninja)
printf 'python: %s\n' (get_latest_release https://github.com/python/cpython)
printf 'zstd:   %s\n' (get_latest_release https://github.com/facebook/zstd)
