#!/usr/bin/env bash

set -eux

function install_packages() {
    zypper -n -q ar https://cli.github.com/packages/rpm/gh-cli.repo

    zypper -n -q --gpg-auto-import-keys dup

    packages=(
        # arc
        php

        # b4
        python3-{dkimpy,requests}

        # compression/decompression/extraction
        bzip2
        gzip
        lzop
        lz4
        pbzip2
        pigz
        tar
        unzip
        xz
        zstd

        # cvise
        cvise
        python3-chardet

        # development
        ccache
        make
        patch
        python2
        python3
        texinfo

        # distrobox
        bc
        curl
        diffutils
        findutils
        less
        libvte-2*
        lsof
        pinentry
        shadow
        sudo
        time
        util-linux
        wget

        # email
        cyrus-sasl-plain
        mutt

        # env
        bat
        fd
        fish
        fzf
        jq
        moreutils
        neofetch
        openssh
        stow
        vim
        zoxide

        # git
        gh
        git{,-delta,-email}

        # kernel / tuxmake
        bison
        cpio
        dwarves
        flex
        gcc
        gcc-c++
        libelf-devel
        libopenssl-devel
        ncurses-devel
        perl
        qemu-{arm,extra,ppc,s390x,x86}
        rsync
        socat
        sparse
        u-boot-tools

        # LLVM/clang
        clang
        cmake
        lld
        ninja
        zlib-devel

        # package building
        dpkg-dev
        rpmbuild

        # spdxcheck.py
        python3-GitPython
        python3-ply
    )

    host_arch=$(uname -m)
    # No GCC for you!
    if [[ ! $host_arch =~ arm ]]; then
        packages+=(cross-{arm,mips,ppc64,s390x}-gcc13)
        case "$host_arch" in
            aarch64) packages+=(cross-x86_64-gcc13) ;;
            x86_64) packages+=(cross-aarch64-gcc13) ;;
        esac
    fi

    zypper -n -q in "${packages[@]}"
    # Force reinstall ca-certificates and ca-certificates-mozilla, otherwise
    # curl barfs
    zypper -n -q in -f ca-certificates{,-mozilla}
}

function check_fish() {
    # shellcheck disable=SC2016
    fish_version=$(fish -c 'echo $version' | sed 's;\.;;g')
    if [[ $fish_version -lt 340 ]]; then
        printf "\n%s is too old!\n" "$(fish --version)"
        exit 1
    fi
}

install_packages
check_fish
