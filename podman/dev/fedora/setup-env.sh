#!/usr/bin/env bash

set -eux

function install_packages() {
    dnf update -y

    dnf install -y dnf-plugins-core
    # Disabled for now
    # dnf copr enable -y @fedora-llvm-team/llvm-snapshots
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

    packages=(
        # Generic
        ccache
        curl
        cvise
        fish
        fzf
        gh
        git
        git-email
        glibc-devel
        glibc-static
        jq
        libfl-devel
        make
        mutt
        openssh
        passwd
        patch
        pbzip2
        php
        pigz
        python2
        python3
        python3-dkimpy
        python3-dns
        python3-requests
        stow
        tar
        texinfo-tex
        unzip
        vim
        vte-profile
        zoxide

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
        binutils-devel
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
