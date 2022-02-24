#!/usr/bin/env bash

set -eux

# Edit /etc/pacman.conf
function pacman_conf() {
    sed -i 's/#Color/Color/g' /etc/pacman.conf
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 7/g' /etc/pacman.conf
    sed -i "/\[testing\]/,/Include/"'s/^#//' /etc/pacman.conf
    sed -i "/\[community-testing\]/,/Include/"'s/^#//' /etc/pacman.conf
}

# Edit /etc/makepkg.conf to gain some speed up
function makepkg_conf() {
    # shellcheck disable=SC2016
    sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/g' /etc/makepkg.conf
    sed -i 's/!ccache/ccache/g' /etc/makepkg.conf
}

# Update and install packages
function install_packages() {
    pacman -Syyu --noconfirm

    packages=(
        # Nicer versions of certain GNU utilities
        bat
        diskus
        exa
        fd
        ripgrep

        # arc
        php

        # b4
        python-dkim
        python-requests

        # compression/decompression/extraction
        bzip2
        gzip
        lzop
        lz4
        pbzip2
        pigz
        unzip
        zstd

        # development
        ccache
        hyperfine
        lib32-glibc
        python
        python-setuptools
        python-yaml

        # distrobox
        vte-common

        # email
        mutt

        # env
        fish
        fzf
        jq
        less
        openssh
        stow
        vim
        zoxide

        # git
        git
        github-cli
        perl-authen-sasl
        perl-mime-tools
        perl-net-smtp-ssl

        # kernel / tuxmake
        aarch64-linux-gnu-gcc
        bc
        bison
        cpio
        flex
        libelf
        ncurses
        openssl
        pahole
        rsync
        socat
        uboot-tools
        wget

        # LLVM/clang
        clang
        cmake
        lld
        llvm
        ninja

        # package building
        dpkg
        pacman-contrib
        rpm-tools

        # spdxcheck.py
        python-gitpython
        python-ply

        # QEMU
        libevent
        libutempter
        qemu-headless-arch-extra
    )
    pacman -S --noconfirm "${packages[@]}"
}

# Setup build user for AUR packages
function setup_build_user() {
    useradd -m build
    echo "build ALL=(ALL) NOPASSWD: ALL" >/etc/sudoers.d/build
}

pacman_conf
makepkg_conf
install_packages
setup_build_user
