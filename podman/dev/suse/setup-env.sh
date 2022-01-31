#!/usr/bin/env bash

set -eux

function install_packages() {
    zypper -n -q ar https://cli.github.com/packages/rpm/gh-cli.repo

    zypper -n -q --gpg-auto-import-keys dup

    packages=(
        # Generic
        ccache
        cyrus-sasl-plain
        curl
        cvise
        findutils
        fish
        fzf
        gh
        git
        git-email
        jq
        libvte-2*
        make
        mutt
        patch
        php
        python2
        python3
        python3-chardet
        python3-dkimpy
        python3-requests
        shadow
        stow
        sudo
        tar
        texinfo
        unzip
        util-linux
        vim

        # Kernel
        bc
        bison
        bzip2
        cpio
        cross-{arm,mips,ppc64,s390x}-gcc11
        dwarves
        flex
        gcc
        gcc-c++
        gzip
        libelf-devel
        libopenssl-devel
        lz4
        lzop
        ncurses-devel
        pbzip2
        perl
        pigz
        qemu-{arm,extra,ppc,s390x,x86}
        rsync
        socat
        u-boot-tools
        wget
        xz
        zstd

        # LLVM/clang
        clang
        cmake
        lld
        ninja
        zlib-devel
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
