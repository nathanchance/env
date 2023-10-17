#!/usr/bin/env bash

set -eu

function setup_fish_repo() {
    export DEBIAN_FRONTEND=noninteractive

    apt-config dump | grep -we Recommends -e Suggests | sed 's/1/0/g' | tee /etc/apt/apt.conf.d/999norecommend

    apt-get update -qq

    apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg

    # shellcheck disable=SC1091
    source /usr/lib/os-release
    # Until OBS supports Debian 12, dependencies should be fine
    (
        VERSION_ID=11
        curl -fLSs https://download.opensuse.org/repositories/shells:fish:release:3/Debian_"$VERSION_ID"/Release.key | gpg --dearmor | dd of=/etc/apt/trusted.gpg.d/shells_fish_release_3.gpg
        echo "deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_$VERSION_ID/ /" | tee /etc/apt/sources.list.d/shells:fish:release:3.list
    )
}

function setup_gh_repo() {
    curl -fLSs https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/trusted.gpg.d/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | tee /etc/apt/sources.list.d/github-cli.list
}

function setup_llvm_repo() {
    curl -fLSs https://apt.llvm.org/llvm-snapshot.gpg.key | gpg --dearmor | dd of=/etc/apt/trusted.gpg.d/apt_llvm_org.gpg

    llvm_main=18
    llvm_stable=17
    llvm_versions=(
        "$llvm_main"
        "$llvm_stable"
        16
        15
    )

    for llvm_version in "${llvm_versions[@]}"; do
        case $llvm_version in
            "$llvm_main") ;;
            *) deb_suffix=-$llvm_version ;;
        esac
        echo "deb http://apt.llvm.org/$VERSION_CODENAME/ llvm-toolchain-$VERSION_CODENAME${deb_suffix:-} main" | tee /etc/apt/sources.list.d/llvm-"$llvm_version".list
    done

    # These are not in Bookworm, they should be safe through dependency checks
    # though. 11 and 12 cannot be satisfied by the packages in Bookworm unfortunately.
    old_llvm_versions=(
        14
        13
    )
    for old_llvm_version in "${old_llvm_versions[@]}"; do
        echo "deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-$old_llvm_version main" | tee /etc/apt/sources.list.d/llvm-"$old_llvm_version".list
    done
    llvm_versions+=("${old_llvm_versions[@]}")
}

function install_packages() {
    packages=(
        # arc
        php

        # b4
        python3{,-dkim,-requests}

        # build-binutils.py
        file
        texinfo

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
        bc
        curl
        diffutils
        iputils-ping
        less
        libvte-*-common
        lsof
        pinentry-curses
        sudo
        time
        tree
        tzdata
        wget
        xauth
        zip

        # env
        ca-certificates
        fish
        fzf
        jq
        locales
        moreutils
        neofetch
        openssh-client
        stow
        vim
        zoxide

        # git
        gh
        git
        git-email
        libauthen-sasl-perl
        libio-socket-ssl-perl

        # kernel / tuxmake
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
        sparse
        u-boot-tools

        # LLVM
        binutils-dev
        cmake
        ninja-build
        python3-distutils
        zlib1g-dev

        # llvm.sh
        lsb-release
        software-properties-common

        # package building
        dpkg
        rpm

        # spdxcheck.py
        python3-git
        python3-ply
    )
    for llvm_version in "${llvm_versions[@]}"; do
        packages+=(
            clang-"$llvm_version"
            lld-"$llvm_version"
            llvm-"$llvm_version"
        )
    done

    apt-get update -qq

    apt-get dist-upgrade -y

    apt-get install -y "${packages[@]}"

    rm -fr /var/lib/apt/lists/*

    ln -fsv /usr/lib/llvm-"$llvm_stable"/bin/* /usr/local/bin

    # Install delta from GitHub
    case "$(uname -m)" in
        aarch64) delta_arch=arm64 ;;
        x86_64) delta_arch=amd64 ;;
    esac
    api_args=()
    if [[ -n ${GITHUB_TOKEN:-} ]]; then
        api_args=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Content-Type: application/json"
        )
    fi
    delta_repo=dandavison/delta
    delta_version=$(curl "${api_args[@]}" -LSs https://api.github.com/repos/"$delta_repo"/releases/latest | jq -r .tag_name)
    delta_deb=/tmp/git-delta_"$delta_version"_"$delta_arch".deb
    curl -LSso "$delta_deb" https://github.com/"$delta_repo"/releases/download/"$delta_version"/"${delta_deb##*/}"
    apt install -y "$delta_deb"
    rm -fr "$delta_deb"
}

function check_fish() {
    # shellcheck disable=SC2016
    fish_version=$(fish -c 'echo $version' | sed 's;\.;;g')
    if [[ $fish_version -lt 340 ]]; then
        printf "\n%s is too old!\n" "$(fish --version)"
        exit 1
    fi
}

function setup_locales() {
    echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
    echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
    rm -f /etc/locale.gen
    dpkg-reconfigure --frontend noninteractive locales
}

function build_pahole() {
    pahole_ver=1.25
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

    command -v pahole
    pahole --version

    cd
    rm -r "$pahole_src"
}

function check_tools() {
    for binary in clang ld.lld llvm-objcopy; do
        "$binary" --version | head -n1
        for llvm_version in "${llvm_versions[@]}"; do
            "$binary-$llvm_version" --version | head -n1
        done
    done
}

setup_fish_repo
setup_gh_repo
setup_llvm_repo
install_packages
check_fish
setup_locales
build_pahole
check_tools
