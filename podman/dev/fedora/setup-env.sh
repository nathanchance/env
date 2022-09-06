#!/usr/bin/env bash

set -eux

function install_packages() {
    dnf update -y

    dnf install -y \
        curl \
        dnf-plugins-core
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    # https://github.com/cli/cli/issues/6175
    sed -i 's/0xc99b11deb97541f0/0x23F3D4EA75716059/g' /etc/yum.repos.d/gh-cli.repo
    cat <<EOF >/etc/yum.repos.d/tuxmake.repo
[tuxmake]
name=tuxmake
type=rpm-md
baseurl=https://tuxmake.org/packages/
gpgcheck=1
gpgkey=https://tuxmake.org/packages/repodata/repomd.xml.key
enabled=1
EOF

    packages=(
        # arc
        php

        # b4
        b4

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
        glibc-devel
        glibc-static
        libfl-devel
        make
        patch
        python2
        python3
        python3-yapf
        texinfo-tex

        # distrobox
        bc
        diffutils
        less
        passwd
        pinentry
        tree
        vte-profile
        wget

        # env
        bat
        fd-find
        fish
        fzf
        jq
        python-unversioned-command
        openssh
        stow
        vim
        zoxide

        # email
        cyrus-sasl-plain
        lei
        mutt

        # git
        gh
        git{,-delta,-email}

        # kernel / tuxmake
        bison
        cpio
        {binutils,gcc}-{arm,mips64,powerpc64{,le},riscv64,s390x}-linux-gnu
        dwarves
        elfutils-libelf-devel
        flex
        gcc
        gcc-c++
        gmp-devel
        libmpc-devel
        ncurses-devel
        openssl
        openssl-devel
        perl
        qemu-img
        qemu-system-{aarch64,arm,mips,ppc,riscv,s390x,x86}
        rsync
        socat
        sparse
        tuxmake
        uboot-tools

        # LLVM/clang + build-llvm.py
        binutils-devel
        clang
        cmake
        lld
        ninja-build
        perf
        zlib-devel

        # locale
        glibc-langpack-en

        # nicer GNU utilities
        exa
        ripgrep

        # package building
        dpkg-dev
        rpm-build

        # spdxcheck.py
        python3-GitPython
        python3-ply
    )

    case "$(uname -m)" in
        aarch64) packages+=({binutils,gcc}-x86_64-linux-gnu) ;;
        x86_64) packages+=({binutils,gcc}-aarch64-linux-gnu) ;;
    esac

    dnf install -y "${packages[@]}"
}

function check_fish() {
    # shellcheck disable=SC2016
    fish_version=$(fish -c 'echo $version' | sed -e 's;-.*$;;g' -e 's;\.;;g')
    if [[ $fish_version -lt 340 ]]; then
        printf "\n%s is too old!\n" "$(fish --version)"
        exit 1
    fi
}

install_packages
check_fish
