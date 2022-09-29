#!/usr/bin/env bash

set -eux

# Edit /etc/pacman.conf
function pacman_conf() {
    sed -i 's/^#Color/Color/g' /etc/pacman.conf
    sed -i 's/^NoProgressBar/#NoProgressBar/g' /etc/pacman.conf
    sed -i 's/^#ParallelDownloads = 5/ParallelDownloads = 7/g' /etc/pacman.conf
    sed -i "/\[testing\]/,/Include/"'s/^#//' /etc/pacman.conf
    sed -i "/\[community-testing\]/,/Include/"'s/^#//' /etc/pacman.conf

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
        edk2-armvirt
        edk2-ovmf
        libevent
        libutempter
        qemu-emulators-full
        qemu-img
    )
    pacman -S --noconfirm "${packages[@]}"
}

function build_pahole() {
    pahole_src=/tmp/dwarves-1.24
    pahole_build=$pahole_src/build

    tar -C "${pahole_src%/*}" -xJf "$pahole_src".tar.xz
    patch -d "$pahole_src" -p1 </tmp/f01e5f3a849558b8ed6b310686d10738f4c2f3bf.patch

    mkdir "$pahole_build"
    cd "$pahole_build"

    cmake \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -D__LIB=lib \
        "$pahole_src"

    make -j"$(nproc)" install

    command -v pahole
    pahole --version

    cd
    rm -r "$pahole_src"{,.tar.xz} /tmp/f01e5f3a849558b8ed6b310686d10738f4c2f3bf.patch
}

pacman_conf
makepkg_conf
gen_locale
add_grep_wrappers
install_packages
build_pahole
