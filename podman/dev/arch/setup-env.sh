#!/usr/bin/env bash

set -eux

# Edit /etc/pacman.conf
function pacman_conf() {
    sed -i 's/#Color/Color/g' /etc/pacman.conf
    sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 7/g' /etc/pacman.conf
    sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
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

        # Generic
        ccache
        git
        hyperfine
        fish
        less
        python
        python-setuptools
        python-yaml
        vim

        # Kernel
        aarch64-linux-gnu-gcc
        bc
        bison
        bzip2
        cpio
        dpkg
        flex
        gzip
        libelf
        lzop
        lz4
        ncurses
        openssl
        pahole
        rsync
        socat
        uboot-tools
        wget
        zstd

        # LLVM/clang
        clang
        cmake
        lld
        llvm
        ninja

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
