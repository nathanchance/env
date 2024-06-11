#!/bin/sh

set -eux

# Update and install packages
install_packages() {
    apk update
    apk upgrade

    cat /tmp/packages/* | xargs apk add
}

build_pahole() {
    pahole_src=/tmp/dwarves-1.27
    pahole_build=$pahole_src/build

    tar -C "${pahole_src%/*}" -xJf "$pahole_src".tar.xz

    mkdir "$pahole_build"
    cd "$pahole_build"

    apk add \
        argp-standalone \
        musl-obstack \
        musl-obstack-dev
    cmake \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_BUILD_TYPE=Release \
        -D__LIB=lib \
        "$pahole_src"

    make -j"$(nproc)" install
    apk del \
        argp-standalone \
        musl-obstack-dev

    command -v pahole
    pahole --version

    cd
}

cleanup() {
    rm -r \
        "$pahole_src" \
        "$pahole_src".tar.xz \
        /tmp/packages
    rm -fr /tmp/*.patch
}

install_packages
build_pahole
cleanup
