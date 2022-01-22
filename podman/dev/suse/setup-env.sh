#!/usr/bin/env bash

set -eux

function install_packages() {
    zypper -n -q up

    packages=(
        # Generic
        ccache
        curl
        cvise
        findutils
        fish
        git
        make
        patch
        python2
        python3
        python3-chardet
        shadow
        sudo
        tar
        texinfo
        util-linux
        vim

        # Kernel
        bc
        bison
        bzip2
        cpio
        cross-arm-gcc11
        cross-mips-gcc11
        cross-ppc64-gcc11
        cross-s390x-gcc11
        dwarves
        flex
        gcc
        gcc-c++
        gzip
        libelf-devel
        libopenssl-devel
        lz4
        lzop
        ncurses-devel
        perl
        qemu-arm
        qemu-extra
        qemu-ppc
        qemu-s390x
        qemu-x86
        rsync
        socat
        u-boot-tools
        wget
        xz
        zstd

        # LLVM/clang
        clang
        cmake
        lld
        ninja
        zlib-devel
    )

    case "$(uname -m)" in
        aarch64) packages+=(cross-x86_64-gcc11) ;;
        x86_64) packages+=(cross-aarch64-gcc11) ;;
    esac

    zypper -n -q in "${packages[@]}"
}

install_packages
