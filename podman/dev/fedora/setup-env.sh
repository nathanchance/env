#!/usr/bin/env bash

set -eux

function install_packages() {
    dnf update -y

    dnf install -y dnf-plugins-core
    # Disabled for now
    # dnf copr enable -y @fedora-llvm-team/llvm-snapshots
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo

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
        passwd
        vte-profile

        # env
        curl
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
        git
        git-email

        # kernel / tuxmake
        bc
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
        uboot-tools
        wget

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
    fish_version=$(fish -c 'echo $version' | sed 's;\.;;g')
    if [[ $fish_version -lt 340 ]]; then
        printf "\n%s is too old!\n" "$(fish --version)"
        exit 1
    fi
}

install_packages
check_fish
