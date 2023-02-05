#!/usr/bin/env bash

set -eu

host_arch=$(uname -m)

function parse_parameters() {
    while (($#)); do
        case $1 in
            docker.io/*)
                image=${1##*/}
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
        software-properties-common
    )
    apt-get install -y --no-install-recommends "${packages[@]}"
    apt-add-repository -y ppa:fish-shell/release-3
}

function setup_apt_llvm_org() {
    [[ $compiler =~ llvm ]] || return 0

    get_apt_gpg_key https://apt.llvm.org/llvm-snapshot.gpg.key apt_llvm_org
    case $compiler in
        llvm-android) ;; # handled later
        llvm-13) ;;      # in bullseye repos by default
        llvm-17) add-apt-repository "deb http://apt.llvm.org/$version/ llvm-toolchain-$version main" ;;
        *) add-apt-repository "deb http://apt.llvm.org/$version/ llvm-toolchain-$version-${compiler##*-} main" ;;
    esac
}

function install_packages() {
    packages=(
        # Building kernels
        bison
        build-essential
        bzip2
        ccache
        cpio
        flex
        gzip
        kmod
        libncurses5-dev
        libssl-dev
        lzop
        openssl
        python3
        sparse
        tar
        u-boot-tools
        xz-utils
        zlib1g-dev
        zstd

        # distrobox
        bc
        curl
        diffutils
        less
        libvte-common
        libvte-*-common
        lsof
        pinentry-curses
        sudo
        time
        wget

        # env
        fish
        jq
        vim

        # git + email
        git
        libsasl2-modules
        mutt

        # miscellaneous
        locales

        # pahole
        cmake
        libdw-dev
        libelf-dev

        # qemu
        qemu-system-arm
        qemu-system-mips
        qemu-system-misc
        qemu-system-ppc
        qemu-system-x86

        # tuxmake
        iproute2
        libc-dev
        rsync
        socat
    )

    # Distribution version specific handling:
    #   * lz4 has a different package name
    #   * QEMU firmware is in a different package on later versions
    #   * GCC 5 from kernel.org was linked against the system libraries of isl,
    #     mpc, and mpfr
    case $version in
        xenial)
            packages+=(
                libisl15
                liblz4-tool
                libmpc3
                libmpfr4
            )
            ;;
        *)
            packages+=(
                lz4
                opensbi
                qemu-system-data
                qemu-system-s390x
            )
            [[ $version = "focal" ]] && packages+=(openbios-ppc)
            ;;
    esac

    if [[ $compiler =~ llvm ]]; then
        local num=${compiler##*-}

        packages+=(
            binutils-arm-linux-gnueabi
            binutils-arm-linux-gnueabihf
            binutils-mips-linux-gnu
            binutils-mipsel-linux-gnu
            binutils-powerpc64le-linux-gnu
            binutils-riscv64-linux-gnu
            binutils-s390x-linux-gnu
        )
        case "$host_arch" in
            aarch64)
                packages+=(
                    binutils-x86-64-linux-gnu
                )
                ;;
            x86_64)
                packages+=(
                    binutils-aarch64-linux-gnu
                    binutils-powerpc-linux-gnu
                    binutils-powerpc64-linux-gnu
                )
                ;;
        esac

        # AOSP LLVM is downloaded later
        if [[ $num != "android" ]]; then
            packages+=(
                clang-"$num"
                lld-"$num"
                llvm-"$num"
            )
        fi
    fi

    apt-get update -qq
    apt-get upgrade -y
    apt-get install -y --no-install-recommends "${packages[@]}"
    rm -fr /var/lib/apt/lists/*
}

function setup_gcc() {
    local gcc_ver
    case $compiler in
        gcc-5 | gcc-6 | gcc-7 | gcc-8 | gcc-9) gcc_ver=${compiler##*-}.5.0 ;;
        gcc-10) gcc_ver=10.4.0 ;;
        gcc-11) gcc_ver=11.3.0 ;;
        gcc-12) gcc_ver=12.2.0 ;;
        llvm-*) return 0 ;;
        *) echo "$compiler not added to setup_gcc!" && exit 1 ;;
    esac

    gcc_targets=(
        arm-linux-gnueabi
        m68k-linux
        mips{,64}-linux
        powerpc{,64}-linux
        s390-linux
        x86_64-linux
    )
    # No GCC 5.x aarch64-linux on arm64?
    case "$host_arch:$compiler" in
        aarch64:gcc-5) ;;
        *) gcc_targets+=(aarch64-linux) ;;
    esac
    # No GCC 9.5.0 i386-linux on x86_64?
    case "$host_arch:$compiler" in
        x86_64:gcc-9) ;;
        *) gcc_targets+=(i386-linux) ;;
    esac
    # RISC-V was not supported in GCC until 7.x
    case $compiler in
        gcc-5 | gcc-6) ;;
        *) gcc_targets+=(riscv{32,64}-linux) ;;
    esac

    case $host_arch in
        aarch64) gcc_host_arch=arm64 ;;
        *) gcc_host_arch=$host_arch ;;
    esac
    for gcc_target in "${gcc_targets[@]}"; do
        wget --output-document=/dev/stdout --progress=dot:giga https://mirrors.edge.kernel.org/pub/tools/crosstool/files/bin/"$gcc_host_arch"/"$gcc_ver"/"$gcc_host_arch"-gcc-"$gcc_ver"-nolibc-"$gcc_target".tar.xz |
            tar -C /usr/local --strip-components=2 -xJf -
    done
}

function setup_llvm() {
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
}

function check_fish() {
    # shellcheck disable=SC2016
    fish_version=$(fish -c 'echo $version' | sed 's;\.;;g')
    if [[ $fish_version -lt 340 ]]; then
        printf "\n%s is too old!\n" "$(fish --version)"
        exit 1
    fi
}

function download_install_binary() {
    local binary=$1
    local url=$2
    local workdir=/tmp/$binary

    mkdir -p "$workdir"
    curl -LSs "$url" | tar -C "$workdir" -xzvf -
    install -Dvm0755 -t /usr/local/bin "$workdir"/"$binary"

    cd
    command -v "$binary"
    "$binary" --version
    rm -fr "$workdir"
}

function install_delta() {
    # Install delta from GitHub
    case "$host_arch" in
        aarch64) delta_arch=arm64 ;;
        x86_64) delta_arch=amd64 ;;
    esac
    work_dir=$(mktemp -d)
    delta_repo=dandavison/delta
    api_args=()
    if [[ -n ${GITHUB_TOKEN:-} ]]; then
        api_args=(
            -H "Authorization: Bearer $GITHUB_TOKEN"
            -H "Content-Type: application/json"
        )
    fi
    delta_version=$(curl "${api_args[@]}" -LSs https://api.github.com/repos/"$delta_repo"/releases/latest | jq -r .tag_name)
    case "$host_arch" in
        aarch64)
            case $version in
                # glibc is too old on Xenial
                xenial) ;;
                *) delta_deb=$work_dir/git-delta_"$delta_version"_"$delta_arch".deb ;;
            esac
            ;;
        x86_64)
            # musl binaries are statically linked so they can be used on any version
            delta_deb=$work_dir/git-delta-musl_"$delta_version"_"$delta_arch".deb
            ;;
    esac
    if [[ -n ${delta_deb:-} ]]; then
        curl "${api_args[@]}" -LSso "$delta_deb" https://github.com/"$delta_repo"/releases/download/"$delta_version"/"${delta_deb##*/}"
        apt install -y "$delta_deb"
    fi
    rm -fr "$work_dir"
}

function install_fzf() {
    case "$host_arch" in
        aarch64) fzf_arch=arm64 ;;
        x86_64) fzf_arch=amd64 ;;
    esac
    fzf_url=$(curl "${api_args[@]}" -LSs https://api.github.com/repos/junegunn/fzf/releases/latest | grep -E "browser_download_url.*linux_$fzf_arch" | cut -d\" -f4)
    download_install_binary fzf "$fzf_url"
}

function install_ripgrep() {
    ripgrep_url=$(curl "${api_args[@]}" -LSs https://api.github.com/repos/microsoft/ripgrep-prebuilt/releases/latest | grep -E "browser_download_url.*$host_arch-unknown-linux-musl" | cut -d\" -f4)
    download_install_binary rg "$ripgrep_url"
}

function install_zoxide() {
    zoxide_url=$(curl "${api_args[@]}" -LSs https://api.github.com/repos/ajeetdsouza/zoxide/releases/latest | grep -E "browser_download_url.*$host_arch-unknown-linux-musl" | cut -d\" -f4)
    download_install_binary zoxide "$zoxide_url"
}

function setup_locales() {
    echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
    echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
    rm -f /etc/locale.gen
    dpkg-reconfigure --frontend noninteractive locales
}

function build_pahole() {
    pahole_src=/tmp/dwarves-1.24
    pahole_build=$pahole_src/build

    tar -C "${pahole_src%/*}" -xJf "$pahole_src".tar.xz
    patch -d "$pahole_src" -p1 </tmp/ea30d58a2329764b9515bbe671575260c76f8114.patch

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
    rm -r "$pahole_src"{,.tar.xz} /tmp/ea30d58a2329764b9515bbe671575260c76f8114.patch
}

function check_compilers() {
    case $compiler in
        gcc-*)
            for gcc_target in "${gcc_targets[@]}"; do
                binary=$gcc_target-gcc
                "$binary" --version | head -n1
                echo "int main(void) { return 0; }" | "$binary" -x c -c -o /dev/null -
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
    setup_fish_repo
    setup_apt_llvm_org
    install_packages
    setup_gcc
    setup_llvm
    check_fish
    install_delta
    install_fzf
    install_ripgrep
    install_zoxide
    setup_locales
    build_pahole
    check_compilers
}

parse_parameters "$@"
setup_environment
