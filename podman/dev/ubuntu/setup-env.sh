#!/usr/bin/env bash

set -eu

function setup_fish_repo() {
    export DEBIAN_FRONTEND=noninteractive

    apt-config dump | grep -we Recommends -e Suggests | sed 's/1/0/g' | tee /etc/apt/apt.conf.d/999norecommend

    apt-get update -qq

    apt-get install -qq \
        gpg-agent \
        software-properties-common

    apt-add-repository -y ppa:fish-shell/release-3
}

function install_packages() {
    packages=(
        # Generic
        build-essential
        ca-certificates
        ccache
        curl
        cvise
        fish
        git
        gzip
        libvte-common
        locales
        python3
        sudo
        vim
        wget

        # Kernel
        bc
        {binutils,gcc}-aarch64-linux-gnu
        {binutils,gcc}-arm-linux-gnueabi
        {binutils,gcc}-arm-linux-gnueabihf
        {binutils,gcc}-mips{,el}-linux-gnu
        {binutils,gcc}-riscv64-linux-gnu
        {binutils,gcc}-s390x-linux-gnu
        bison
        bzip2
        cpio
        flex
        kmod
        libc-dev
        libdw-dev
        libelf-dev
        libncurses5-dev
        libssl-dev
        lz4
        lzop
        openssl
        qemu-system-{arm,mips,misc,ppc,x86}
        rsync
        socat
        tar
        u-boot-tools
        xz-utils
        zlib1g-dev
        zstd

        # LLVM
        clang
        cmake
        lld
        llvm
        ninja-build
        python3-distutils
    )

    apt-get update -qq

    apt-get upgrade -qq

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
install_packages
setup_locales
build_pahole
check_tools
