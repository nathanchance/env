#!/usr/bin/env bash

set -eux

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

function install_packages() {
    dnf update -y

    dnf install -y \
        curl \
        dnf-plugins-core
    dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
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
        lsof
        passwd
        pinentry
        time
        vte-profile
        wget

        # env
        bat
        fd-find
        fish
        fzf
        jq
        moreutils
        neofetch
        openssh
        python-unversioned-command
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

        # pahole
        elfutils-devel

        # spdxcheck.py
        python3-GitPython
        python3-ply

        # website management
        hugo
        iproute
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

function build_pahole() {
    pahole_src=/tmp/dwarves-1.24
    pahole_build=$pahole_src/build

    tar -C "${pahole_src%/*}" -xJf "$pahole_src".tar.xz
    patch -d "$pahole_src" -p1 </tmp/dwarves.patch

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
    rm -r "$pahole_src"{,.tar.xz} /tmp/*.patch
}

add_grep_wrappers
install_packages
check_fish
build_pahole
