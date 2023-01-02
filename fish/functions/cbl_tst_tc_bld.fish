#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_tst_tc_bld -d "Test build-llvm.py and build-binutils.py in Docker images"
    set ccache_folder $CBL/.config/ccache/cbl_lkt_tc_bld
    set tc_bld $CBL_GIT/tc-build
    set script (mktemp -p $tc_bld --suffix=.sh)

    set log (mktemp)
    echo "Log: $log"

    mkdir -p $ccache_folder

    if not test -f $tc_bld/build-llvm.py
        print_error "$tc_bld/build-llvm.py does not exist!"
        return 1
    end

    echo '#!/usr/bin/env bash
set -x
PACKAGES=(ccache clang cmake git python3)
# Debian/Ubuntu
if command -v apt-get &>/dev/null; then
    PACKAGES+=(
        bc
        binutils-dev
        bison
        ca-certificates
        curl
        file
        flex
        gcc
        g++
        lld
        libelf-dev
        libssl-dev
        make
        ninja-build
        texinfo
        u-boot-tools
        xz-utils
        zlib1g-dev
    )
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y "${PACKAGES[@]}"
# Fedora
elif command -v dnf &>/dev/null; then
    PACKAGES+=(
        bc
        binutils-devel
        bison
        elfutils-libelf-devel
        flex
        gcc
        gcc-c++
        lld
        make
        ninja-build
        openssl-devel
        texinfo-tex
        uboot-tools
        xz
        zlib-devel
    )
    dnf update -y
    dnf install -y "${PACKAGES[@]}"
# Arch
elif command -v pacman &>/dev/null; then
    PACKAGES+=(
        bc
        base-devel
        bison
        flex
        libelf
        lld
        ninja
        openssl
        uboot-tools
    )
    pacman -Syyu --noconfirm
    pacman -S --noconfirm "${PACKAGES[@]}"
# Clear Linux
elif command -v swupd &>/dev/null; then
    PACKAGES=(
        c-basic
        ccache
        curl
        dev-utils
        devpkg-elfutils
        devpkg-openssl
        git
        python3-basic
        which
    )
    swupd update
    swupd bundle-add "${PACKAGES[@]}"
    # Build u-boot-tools
    (
        UBOOT_VERSION=u-boot-2021.10
        cd /usr/src
        curl -LSs https://ftp.denx.de/pub/u-boot/"${UBOOT_VERSION}".tar.bz2 | tar -xjf -
        cd "${UBOOT_VERSION}" || exit ${?}
        make -j"$(nproc)" defconfig tools-all || exit ${?}
        install -Dm755 tools/mkimage /usr/local/bin/mkimage
        mkimage -V
    ) || exit ${?}
# OpenSUSE Leap/Tumbleweed
elif command -v zypper &>/dev/null; then
    PACKAGES+=(
        bc
        binutils-devel
        binutils-gold
        bison
        ccache
        clang
        cmake
        curl
        flex
        gcc
        gcc-c++
        git
        gzip
        libelf-devel
        libopenssl-devel
        lld
        make
        ninja
        python3
        tar
        texinfo
        u-boot-tools
        xz
        zlib-devel
    )
    zypper -n up
    zypper -n in "${PACKAGES[@]}"
fi
TMP=$(mktemp -d)
cp -v "$(command -v ccache)" "${TMP}"
for BINARY in cc c++ clang clang++ gcc g++; do
    ln -fsv ccache "${TMP}/${BINARY}"
done
ccache --max-size=100G
ccache --set-config=compression=true
ccache --set-config=compression_level=9
ccache --show-stats
PATH=${TMP}:${PATH} ./build-binutils.py || exit ${?}
CC=gcc ./build-llvm.py --branch "release/13.x" || exit ${?}
# Clear Linux defines these in the environment and it causes issues
# We do not do this sooner because we want the optimized flags that Clear Linux provides for GCC
unset CC CFLAGS CXX CXXFLAGS
CC=clang ./build-llvm.py --branch "release/13.x" || exit ${?}
for FILE in clang ld.lld aarch64-linux-gnu-as arm-linux-gnueabi-as m68k-linux-gnu-as mips-linux-gnu-as mipsel-linux-gnu-as powerpc-linux-gnu-as powerpc64-linux-gnu-as powerpc64le-linux-gnu-as riscv64-linux-gnu-as s390x-linux-gnu-as as; do
    install/bin/${FILE} --version || exit ${?}
done
rm -rf /linux/out
kernel/build.sh -s /linux -t "PowerPC;X86"' >$script

    set images \
        archlinux \
        clearlinux \
        debian:buster \
        debian:stable \
        debian:testing \
        debian:unstable \
        fedora \
        fedora:rawhide \
        opensuse/leap \
        opensuse/tumbleweed \
        ubuntu:20.04 \
        ubuntu \
        ubuntu:rolling \
        ubuntu:devel

    for image in $images
        rm -rf $tc_bld/install
        podman pull docker.io/$image
        if podman run \
                --env="CCACHE_DIR=$ccache_folder" \
                --interactive \
                --rm \
                --tty \
                --volume="$ccache_folder:$ccache_folder" \
                --volume="$tc_bld:$tc_bld" \
                --volume="$CBL_BLD_P/linux:/linux" \
                --workdir="$tc_bld" \
                docker.io/$image bash $script
            echo "$image successful" >>$log
        else
            echo "$image failed" >>$log
        end
    end
    rm $script

    echo
    echo "Results:"
    cat $log
    mail_msg $log
    echo

end
