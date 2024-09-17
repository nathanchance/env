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

    # https://lwn.net/ml/fedora-devel/CAPtvTsZMBi98PbpwR5NydijsfLAhoQ0GO890jzN4FPd66f0gBw@mail.gmail.com/
    if ! command dnf &>/dev/null; then
        dnf5 install -y dnf
    fi

    dnf install -y \
        curl \
        dnf-plugins-core

    # https://github.com/rpm-software-management/dnf5/issues/405
    # dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    curl -LSso /etc/yum.repos.d/gh-cli.repo https://cli.github.com/packages/rpm/gh-cli.repo

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
        python3
        python3-yapf
        texinfo-tex

        # distrobox
        bc
        cracklib-dicts
        diffutils
        doas
        hostname
        iputils
        less
        lsof
        passwd
        pinentry
        procps-ng
        time
        tree
        tzdata
        util-linux-script
        vte-profile
        wget
        xorg-x11-xauth

        # env
        bat
        fastfetch
        fd-find
        fish
        fzf
        jq
        moreutils
        openssh
        python-unversioned-command
        stow
        tmux
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
        openssl{,-devel{,-engine}}
        perl
        qemu-{guest-agent,img}
        qemu-system-{aarch64,arm,loongarch64,mips,ppc,riscv,s390x,x86}
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
        eza
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

    # Remove sudo in favor of doas but leave a symlink for compatibility
    rm -f /etc/dnf/protected.d/sudo.conf
    if dnf list --installed sudo &>/dev/null; then
        dnf remove -y sudo
    fi
    ln -frsv /usr/{bin/doas,local/bin/sudo}
}

function check_fish() {
    # shellcheck disable=SC2016
    fish_version=$(fish -c 'echo $version' | sed -e 's;-.*$;;g' -e 's;\.;;g')
    if [[ $fish_version -lt 340 ]]; then
        printf "\n%s is too old!\n" "$(fish --version)"
        exit 1
    fi
}

add_grep_wrappers
install_packages
check_fish
