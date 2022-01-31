#!/usr/bin/env bash

set -eu

function setup_fish_repo() {
    export DEBIAN_FRONTEND=noninteractive

    apt-config dump | grep -we Recommends -e Suggests | sed 's/1/0/g' | tee /etc/apt/apt.conf.d/999norecommend

    apt-get update -qq

    apt-get install -qq \
        curl \
        gnupg \
        software-properties-common

    apt-add-repository -y ppa:fish-shell/release-3
}

function setup_gh_repo() {
    curl -fLSs https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list >/dev/null
}

function install_packages() {
    packages=(
        # arc
        php

        # b4
        python3{,-dkim,-requests}

        # cvise
        cvise

        # compression / decompression / extraction
        bzip2
        gzip
        lzop
        lz4
        pbzip2
        pigz
        tar
        unzip
        xz-utils
        zstd

        # development
        build-essential
        ccache

        # distrobox
        libvte-common
        sudo

        # env
        ca-certificates
        curl
        fish
        jq
        locales
        openssh-client
        stow
        wget
        vim
        zoxide

        # git
        gh
        git
        git-email
        libauthen-sasl-perl
        libio-socket-ssl-perl

        # kernel / tuxmake
        bc
        {binutils,gcc}-{aarch64,mips{,el},riscv64,s390x}-linux-gnu
        {binutils,gcc}-arm-linux-gnueabi{,hf}
        bison
        cpio
        flex
        kmod
        lib{c,dw,elf,ncurses5,ssl}-dev
        openssl
        qemu-system-{arm,mips,misc,ppc,x86}
        rsync
        socat
        u-boot-tools

        # LLVM
        clang
        cmake
        lld
        llvm
        ninja-build
        python3-distutils
        zlib1g-dev

        # package building
        dpkg
        rpm
    )

    apt-get update -qq

    apt-get dist-upgrade -qq

    apt-get install -qq "${packages[@]}"

    rm -fr /var/lib/apt/lists/*

    ln -fsv /usr/lib/llvm-*/bin/* /usr/local/bin
}

function setup_locales() {
    echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
    echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
    rm -f /etc/locale.gen
    dpkg-reconfigure --frontend noninteractive locales
}

function build_pahole() {
    pahole_ver=1.23
    pahole_src=/tmp/dwarves-$pahole_ver
    pahole_build=$pahole_src/build

    curl -LSs https://fedorapeople.org/~acme/dwarves/"${pahole_src##*/}".tar.xz | tar -C "${pahole_src%/*}" -xJf -

    mkdir "$pahole_build"
    cd "$pahole_build"

    cmake \
        -DBUILD_SHARED_LIBS=OFF \
        -D__LIB=lib \
        "$pahole_src"

    make -j"$(nproc)" install

    cd
    rm -r "$pahole_src"
}

function check_tools() {
    for binary in clang ld.lld llvm-objcopy; do
        "$binary" --version | head -n1
    done
}

setup_fish_repo
setup_gh_repo
install_packages
setup_locales
build_pahole
check_tools
