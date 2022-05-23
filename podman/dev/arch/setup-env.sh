#!/usr/bin/env bash

set -eux

# Edit /etc/pacman.conf
function pacman_conf() {
    sed -i 's/^#Color/Color/g' /etc/pacman.conf
    sed -i 's/^NoProgressBar/#NoProgressBar/g' /etc/pacman.conf
    sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 7/g' /etc/pacman.conf
    sed -i "/\[testing\]/,/Include/"'s/^#//' /etc/pacman.conf
    sed -i "/\[community-testing\]/,/Include/"'s/^#//' /etc/pacman.conf

    cat <<'EOF' >>/etc/pacman.conf

[nathan]
SigLevel = Optional TrustAll
Server = https://raw.githubusercontent.com/nathanchance/arch-repo/main/$arch
EOF

    cat /etc/pacman.conf
}

# Edit /etc/makepkg.conf to gain some speed up
function makepkg_conf() {
    # shellcheck disable=SC2016
    sed -i 's/^#MAKEFLAGS="-j2"/MAKEFLAGS="-j$(nproc)"/g' /etc/makepkg.conf
    sed -i 's/^!ccache/ccache/g' /etc/makepkg.conf

    cat /etc/makepkg.conf
}

# Update and install packages
function install_packages() {
    pacman -Syyuu --noconfirm

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
        b4
        python-dkim
        patatt

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
        shellcheck-bin
        shfmt
        yapf

        # distrobox
        bc
        curl
        diffutils
        less
        pinentry
        tree
        vte-common
        wget

        # email
        lei
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

        # frame-larger-than.py
        python-pyelftools

        # git
        git
        github-cli
        perl-authen-sasl
        perl-mime-tools
        perl-net-smtp-ssl

        # kernel / tuxmake
        aarch64-linux-gnu-gcc
        arm-none-eabi-gcc
        bison
        cpio
        flex
        libelf
        inetutils
        mkinitcpio
        ncurses
        openssl
        pahole
        picocom
        riscv64-linux-gnu-gcc
        rsync
        socat
        sparse
        tuxmake
        uboot-tools

        # LLVM/clang + build-llvm.py
        clang
        cmake
        cvise
        lld
        llvm
        ninja
        perf

        # package building
        dpkg
        pacman-contrib
        rpm-tools

        # spdxcheck.py
        python-gitpython
        python-ply

        # QEMU
        edk2-armvirt
        edk2-ovmf
        libevent
        libutempter
        qemu-emulators-full
        qemu-img
    )
    pacman -S --noconfirm "${packages[@]}"
}

pacman_conf
makepkg_conf
install_packages
