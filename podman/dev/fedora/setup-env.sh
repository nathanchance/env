#!/usr/bin/env bash

set -eux

function install_packages() {
    dnf update -y

    packages=(
        # Generic
        ccache
        curl
        cvise
        fish
        git
        glibc-devel
        libfl-devel
        make
        patch
        python2
        python3
        tar
        texinfo-tex
        vim

        # Kernel
        bc
        bison
        bzip2
        cpio
        {binutils,gcc}-arm-linux-gnu
        {binutils,gcc}-mips64-linux-gnu
        {binutils,gcc}-powerpc64-linux-gnu
        {binutils,gcc}-powerpc64le-linux-gnu
        {binutils,gcc}-riscv64-linux-gnu
        {binutils,gcc}-s390x-linux-gnu
        dpkg-dev
        dwarves
        elfutils-libelf-devel
        flex
        gcc
        gcc-c++
        gmp-devel
        gzip
        libmpc-devel
        lz4
        lzop
        ncurses-devel
        openssl
        openssl-devel
        perl
        qemu-system-aarch64
        qemu-system-arm
        qemu-system-mips
        qemu-system-ppc
        qemu-system-riscv
        qemu-system-s390x
        qemu-system-x86
        rpm-build
        rsync
        socat
        uboot-tools
        wget
        xz
        zstd

        # LLVM/clang
        clang
        cmake
        lld
        ninja-build
        zlib-devel
    )

    case "$(uname -m)" in
        aarch64) packages+=({binutils,gcc}-x86_64-linux-gnu) ;;
        x86_64) packages+=({binutils,gcc}-aarch64-linux-gnu) ;;
    esac

    dnf install -y "${packages[@]}"
}

install_packages
