#!/usr/bin/env bash

set -eux

# Edit /etc/pacman.conf
function pacman_conf() {
    sed -i 's/^CheckSpace/#CheckSpace/g' /etc/pacman.conf
    sed -i 's/^#VerbosePkgLists/VerbosePkgLists/g' /etc/pacman.conf
    sed -i 's/^#Color/Color/g' /etc/pacman.conf
    sed -i 's/^NoProgressBar/#NoProgressBar/g' /etc/pacman.conf
    sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 7/g' /etc/pacman.conf
    sed -i "/\[core-testing\]/,/Include/"'s/^#//' /etc/pacman.conf
    sed -i "/\[extra-testing\]/,/Include/"'s/^#//' /etc/pacman.conf

    # Get rid of slimming Docker image changes
    sed -i -e "/home\/custompkgs/,/\[options\]/"'s;\[options\];#\[options\];' -e 's;^NoExtract;#NoExtract;g' /etc/pacman.conf

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

function gen_locale() {
    sed -i 's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/g' /etc/locale.gen
    locale-gen
}

function add_grep_wrappers() {
    cat <<'EOF' >/usr/local/bin/egrep
#!/bin/sh

exec grep -E "$@"
EOF
    cat <<'EOF' >/usr/local/bin/fgrep
#!/bin/sh

exec grep -F "$@"
EOF
    chmod 755 /usr/local/bin/{e,f}grep
}

# Update and install packages
function install_packages() {
    # Update archlinux-keyring via partial upgrade and regenerate the keyring
    # based on it, in case any new packages are signed with those new keys
    pacman -Sy --noconfirm archlinux-keyring
    rm -fr /etc/pacman.d/gnupg
    pacman-key --init
    pacman-key --populate

    pacman -Syyuu --noconfirm

    packages=(
        # Nicer versions of certain GNU utilities
        bat{,-extras}
        diskus
        exa
        fd
        ripgrep

        # arc
        php

        # b4
        b4
        git-filter-repo
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
        ruff
        shellcheck-bin
        shfmt
        yapf

        # distrobox
        bc
        curl
        diffutils
        less
        lsof
        pinentry
        time
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
        moreutils
        neofetch
        openssh
        stow
        tmuxp
        vim{,-spell-en}
        zoxide

        # frame-larger-than.py
        python-pyelftools

        # git
        git{,-delta}
        github-cli
        perl-authen-sasl
        perl-mime-tools
        perl-net-smtp-ssl
        repo

        # kernel / tuxmake
        {{aarch,powerpc,riscv}64,mips,s390x}-linux-gnu-binutils
        arm-linux-gnueabi-binutils
        bison
        cpio
        flex
        libelf
        inetutils
        mkinitcpio
        ncurses
        openssl
        pahole
        rsync
        socat
        sparse
        tio
        tuxmake
        uboot-tools

        # kup
        perl-config-simple

        # LLVM/clang + build-llvm.py
        clang
        cmake
        cvise
        lld
        llvm
        ninja
        perf

        # man pages
        man-db

        # package building
        dpkg
        pacman-contrib
        rpm-tools

        # spdxcheck.py
        python-gitpython
        python-ply

        # QEMU
        edk2-aarch64
        edk2-ovmf
        libevent
        libutempter
        qemu-emulators-full
        qemu-img
        virtiofsd

        # website management
        hugo
        iproute2
    )
    pacman -S --noconfirm "${packages[@]}"
}

pacman_conf
makepkg_conf
gen_locale
add_grep_wrappers
install_packages
