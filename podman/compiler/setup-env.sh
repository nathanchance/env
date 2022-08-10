#!/usr/bin/env bash

set -eu

function parse_parameters() {
    while (($#)); do
        case $1 in
            docker.io/*)
                image=${1##*/}
                base=${image%:*}
                version=${image##*:}
                ;;
            gcc-* | llvm-*)
                compiler=$1
                ;;
        esac
        shift
    done
}

function get_apt_gpg_key() {
    curl -fLSs "$1" | gpg --dearmor | tee /etc/apt/trusted.gpg.d/"$2".gpg >/dev/null
}

function setup_fish_repo() {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    local packages=(
        ca-certificates
        curl
        gnupg
    )
    if [[ $base = "ubuntu" ]]; then
        packages+=(software-properties-common)
        apt-get install -y --no-install-recommends "${packages[@]}"
        apt-add-repository -y ppa:fish-shell/release-3
    elif [[ $base = "debian" ]]; then
        apt-get install -y --no-install-recommends "${packages[@]}"
        local num
        case $version in
            stretch) num=9.0 ;;
            buster) num=10 ;;
            bullseye) num=11 ;;
        esac
        if [[ -n ${num:-} ]]; then
            echo "deb http://download.opensuse.org/repositories/shells:/fish:/release:/3/Debian_$num/ /" | tee /etc/apt/sources.list.d/shells:fish:release:3.list
            get_apt_gpg_key http://download.opensuse.org/repositories/shells:fish:release:3/Debian_$num/Release.key shells_fish_release_3
        fi
    fi
}

function setup_apt_llvm_org() {
    get_apt_gpg_key https://apt.llvm.org/llvm-snapshot.gpg.key apt_llvm_org
    case $compiler in
        llvm-11 | llvm-12 | llvm-14 | llvm-15) add-apt-repository "deb http://apt.llvm.org/$version/ llvm-toolchain-$version-${compiler##*-} main" ;;
        llvm-16) add-apt-repository "deb http://apt.llvm.org/$version/ llvm-toolchain-$version main" ;;
    esac
}

function setup_llvm_copr() {
    dnf update -y
    dnf install -y dnf-plugins-core
    dnf copr enable -y @fedora-llvm-team/llvm-snapshots
}

function install_packages_apt() {
    packages=(
        bc
        binutils-arm-linux-gnueabi
        binutils-arm-linux-gnueabihf
        bison
        build-essential
        bzip2
        ccache
        cmake
        cpio
        curl
        diffutils
        fish
        flex
        git
        gzip
        iproute2
        jq
        kmod
        less
        libc-dev
        libdw-dev
        libelf-dev
        libncurses5-dev
        libsasl2-modules
        libssl-dev
        locales
        lzop
        mutt
        openssl
        pinentry-curses
        python3
        qemu-system-arm
        qemu-system-mips
        qemu-system-misc
        qemu-system-ppc
        qemu-system-x86
        rsync
        socat
        sparse
        sudo
        tar
        tree
        u-boot-tools
        vim
        libvte-common
        libvte-*-common
        wget
        xz-utils
        zlib1g-dev
        zstd
    )

    # Ubuntu has qemu-system-s390x in its own package, Debian has it in
    # qemu-system-misc
    if [[ $base = "ubuntu" ]]; then
        packages+=(qemu-system-x86)
    fi

    # lz4 had a different name on different hosts
    case $version in
        xenial | stretch | bionic)
            packages+=(liblz4-tool)
            ;;
        *)
            packages+=(lz4)
            ;;
    esac

    # Certain packages are not available on non-x86_64 hosts in certain cases
    if [[ $(uname -m) = "x86_64" ]]; then
        packages+=(
            binutils-aarch64-linux-gnu
            binutils-powerpc-linux-gnu
            binutils-powerpc64le-linux-gnu
            binutils-s390x-linux-gnu
        )

        # There is currently no MIPS or powerpc64 GCC 11 package so don't
        # bother installing binutils
        if [[ $compiler != "gcc-11" ]]; then
            packages+=(
                binutils-mips-linux-gnu
                binutils-mipsel-linux-gnu
                binutils-powerpc64-linux-gnu
            )
        fi
    else
        case "$base:$version" in
            debian:stretch | debian:buster | ubuntu:xenial) ;;

            ubuntu:bionic)
                packages+=(
                    binutils-x86-64-linux-gnu
                )
                ;;

            debian:* | ubuntu:*)
                packages+=(
                    binutils-riscv64-linux-gnu
                    binutils-s390x-linux-gnu
                    binutils-x86-64-linux-gnu
                )
                if [[ $compiler != "gcc-11" ]]; then
                    packages+=(
                        binutils-mips-linux-gnu
                        binutils-mipsel-linux-gnu
                    )
                fi
                ;;
        esac
    fi

    case $compiler in
        gcc-*)
            packages+=(
                gcc-arm-linux-gnueabi
                gcc-arm-linux-gnueabihf
                libc-dev-armel-cross
                libc-dev-armhf-cross
            )

            # These packages are not available on non-x86_64 hosts in certain cases
            if [[ $(uname -m) = "x86_64" ]]; then
                packages+=(
                    gcc-aarch64-linux-gnu
                    gcc-powerpc-linux-gnu
                    gcc-powerpc64le-linux-gnu
                    gcc-s390x-linux-gnu
                    libc-dev-arm64-cross
                    libc-dev-powerpc-cross
                    libc-dev-ppc64el-cross
                    libc-dev-s390x-cross
                )

                # These packages do not have a GCC 11.x version
                if [[ $compiler != "gcc-11" ]]; then
                    packages+=(
                        gcc-mips-linux-gnu
                        gcc-mipsel-linux-gnu
                        gcc-powerpc64-linux-gnu
                        libc-dev-mips-cross
                        libc-dev-mipsel-cross
                        libc-dev-ppc64-cross
                    )
                fi

                # RISC-V does not have gcc-5 or gcc-6 packages and the gcc-7
                # package is not recommended:
                # https://lore.kernel.org/r/mhng-d9c7d4ea-1842-41c9-90f0-a7324b883689@palmerdabbelt-glaptop/
                # There is currently not a gcc-11 version of riscv64-linux-gnu-gcc
                # in Ubuntu.
                case $compiler in
                    gcc-5 | gcc-6 | gcc-7 | gcc-11) ;;
                    *)
                        packages+=(
                            binutils-riscv64-linux-gnu
                            gcc-riscv64-linux-gnu
                            libc-dev-riscv64-cross
                        )
                        ;;
                esac
            else
                case "$base:$version" in
                    debian:stretch | debian:buster | ubuntu:xenial) ;;

                    ubuntu:bionic)
                        packages+=(
                            gcc-x86-64-linux-gnu
                            libc-dev-amd64-cross
                        )
                        ;;
                    debian:* | ubuntu:*)
                        packages+=(
                            gcc-riscv64-linux-gnu
                            gcc-s390x-linux-gnu
                            gcc-x86-64-linux-gnu
                            libc-dev-amd64-cross
                            libc-dev-riscv64-cross
                            libc-dev-s390x-cross
                        )
                        # GCC 9 is amd64 only and GCC 11 does not exist for MIPS
                        if [[ $compiler != "gcc-9" && $compiler != "gcc-11" ]]; then
                            packages+=(
                                gcc-mips-linux-gnu
                                gcc-mipsel-linux-gnu
                                libc-dev-mips-cross
                                libc-dev-mipsel-cross
                            )
                        fi
                        ;;
                esac
            fi
            ;;

        # Android's LLVM is downloaded from AOSP, not a distribution
        llvm-android) ;;

        llvm-*)
            local num=${compiler##*-}
            packages+=(
                binutils-riscv64-linux-gnu
                clang-"$num"
                lld-"$num"
                llvm-"$num"
                ripgrep
            )
            ;;
    esac

    apt-get update -qq
    apt-get upgrade -y
    apt-get install -y --no-install-recommends "${packages[@]}"
    rm -fr /var/lib/apt/lists/*
    if [[ $compiler =~ llvm ]]; then
        if [[ $compiler = "llvm-android" ]]; then
            local android_clang
            android_clang=$(curl -LSs 'https://android.googlesource.com/kernel/common/+/refs/heads/android-mainline/build.config.constants?format=TEXT' | base64 -d | grep "^CLANG_VERSION=" | cut -d = -f 2)
            wget --output-document=/dev/stdout --progress=dot:giga https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-"$android_clang".tar.gz |
                tar -C /usr/local -xzf -
        else
            ln -fsv /usr/lib/llvm-*/bin/* /usr/local/bin
        fi
    fi

    # Install delta from GitHub
    case "$(uname -m)" in
        aarch64) delta_arch=arm64 ;;
        x86_64) delta_arch=amd64 ;;
    esac
    work_dir=$(mktemp -d)
    delta_repo=dandavison/delta
    delta_version=$(curl -LSs https://api.github.com/repos/"$delta_repo"/releases/latest | jq -r .tag_name)
    case "$(uname -m)" in
        aarch64)
            case "$base:$version" in
                # glibc is too old for these distributions
                debian:stretch | debian:buster | ubuntu:xenial | ubuntu:bionic) ;;
                *) delta_deb=$work_dir/git-delta_"$delta_version"_"$delta_arch".deb ;;
            esac
            ;;
        x86_64)
            # musl binaries are statically linked so they can be used on any version
            delta_deb=$work_dir/git-delta-musl_"$delta_version"_"$delta_arch".deb
            ;;
    esac
    if [[ -n ${delta_deb:-} ]]; then
        curl -LSso "$delta_deb" https://github.com/"$delta_repo"/releases/download/"$delta_version"/"${delta_deb##*/}"
        apt install -y "$delta_deb"
    fi
    rm -fr "$work_dir"
}

function install_packages_dnf() {
    packages=(
        # Generic
        ccache
        curl
        cvise
        fish
        git
        make
        patch
        python2
        python3
        tar
        texinfo-tex
        vim

        # Kernel
        bc
        bison
        bzip2
        cpio
        binutils-arm-linux-gnu
        binutils-mips64-linux-gnu
        binutils-powerpc64-linux-gnu
        binutils-powerpc64le-linux-gnu
        binutils-riscv64-linux-gnu
        binutils-s390x-linux-gnu
        dpkg-dev
        dwarves
        elfutils-libelf-devel
        flex
        gzip
        lz4
        lzop
        ncurses-devel
        openssl
        openssl-devel
        perl
        qemu-system-aarch64
        qemu-system-arm
        qemu-system-mips
        qemu-system-ppc
        qemu-system-riscv
        qemu-system-s390x
        qemu-system-x86
        rpm-build
        rsync
        socat
        uboot-tools
        wget
        xz
        zstd

        # LLVM/clang
        clang
        lld
        llvm
    )

    case "$(uname -m)" in
        aarch64) packages+=(binutils-x86_64-linux-gnu) ;;
        x86_64) packages+=(binutils-aarch64-linux-gnu) ;;
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

function install_zoxide() {
    zoxide_workdir=/tmp/zoxide
    zoxide_url=$(curl -LSs https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest | grep -E "browser_download_url.*$(uname -m)-unknown-linux-musl" | cut -d\" -f4)

    mkdir -p "$zoxide_workdir"
    curl -LSs "$zoxide_url" | tar -C "$zoxide_workdir" -xzvf -
    install -Dm0755 -t /usr/local/bin "$zoxide_workdir"/zoxide

    cd
    command -v zoxide
    zoxide --version
    rm -rf "$zoxide_workdir"
}

function setup_locales() {
    echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
    echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
    rm -f /etc/locale.gen
    dpkg-reconfigure --frontend noninteractive locales
}

function build_pahole() {
    pahole_src=/tmp/dwarves-1.23
    pahole_build=$pahole_src/build

    tar -C "${pahole_src%/*}" -xJf "$pahole_src".tar.xz
    patch -d "$pahole_src" -p1 </tmp/2f7d61b2bfb59427926867c886595ff28dd50607.patch

    mkdir "$pahole_build"
    cd "$pahole_build"

    cmake \
        -DBUILD_SHARED_LIBS=OFF \
        -D__LIB=lib \
        "$pahole_src"

    make -j"$(nproc)" install

    cd
    rm -r "$pahole_src"{,.tar.xz} /tmp/2f7d61b2bfb59427926867c886595ff28dd50607.patch
}

function check_compilers() {
    case $compiler in
        gcc-*)
            for binary in /usr/bin/*gcc; do
                "$binary" --version | head -n1
            done
            ;;
        llvm-*)
            for binary in clang ld.lld llvm-objcopy; do
                "$binary" --version | head -n1
            done
            ;;
    esac
}

function setup_environment() {
    if command -v dnf &>/dev/null; then
        setup_llvm_copr
        install_packages_dnf
        check_fish
    elif command -v apt &>/dev/null; then
        setup_fish_repo
        setup_apt_llvm_org
        install_packages_apt
        check_fish
        install_zoxide
        setup_locales
        build_pahole
    fi
    check_compilers
}

parse_parameters "$@"
setup_environment
