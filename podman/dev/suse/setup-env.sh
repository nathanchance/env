#!/usr/bin/env bash

set -eux

function install_packages() {
    zypper -n -q ar https://cli.github.com/packages/rpm/gh-cli.repo

    zypper -n -q --gpg-auto-import-keys dup

    packages=(
        # arc
        php

        # b4
        python3-{dkimpy,requests}

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
        make
        patch
        python2
        python3
        texinfo

        # distrobox
        findutils
        libvte-2*
        shadow
        sudo
        util-linux

        # email
        cyrus-sasl-plain
        mutt

        # env
        curl
        fish
        fzf
        jq
        openssh
        stow
        vim

        # git
        gh
        git
        git-email

        # kernel / tuxmake
        bc
        bison
        cpio
        cross-{arm,mips,ppc64,s390x}-gcc11
        dwarves
        flex
        gcc
        gcc-c++
        libelf-devel
        libopenssl-devel
        ncurses-devel
        perl
        qemu-{arm,extra,ppc,s390x,x86}
        rsync
        socat
        u-boot-tools
        wget

        # LLVM/clang
        clang
        cmake
        lld
        ninja
        zlib-devel

        # package building
        dpkg-dev
        rpmbuild
    )

    case "$(uname -m)" in
        aarch64) packages+=(cross-x86_64-gcc11) ;;
        x86_64) packages+=(cross-aarch64-gcc11) ;;
    esac

    zypper -n -q in "${packages[@]}"

    # Install zoxide from GitHub
    zoxide_repo=ajeetdsouza/zoxide
    zoxide_ver=$(curl -fLSs https://api.github.com/repos/"$zoxide_repo"/releases/latest | jq -r .tag_name)
    tmp_dir=$(mktemp -d)
    curl -fLSs https://github.com/"$zoxide_repo"/releases/download/"$zoxide_ver"/zoxide-"$zoxide_ver"-"$(uname -m)"-unknown-linux-musl.tar.gz | tar -C "$tmp_dir" -xzf -
    install -Dvm755 "$tmp_dir"/zoxide /usr/local/bin/zoxide
    rm -fr "$tmp_dir"
}

install_packages
