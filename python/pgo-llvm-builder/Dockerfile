FROM docker.io/debian:10-slim

# LLVM may require an newer version of cmake, download and install the latest
# prebuilt.
ARG CMAKE_VERSION=3.25.3
RUN apt update && \
    apt upgrade -y && \
    apt install -y --no-install-recommends \
        ca-certificates \
        wget \
        && \
    rm -fr /var/lib/apt/lists/* && \
    url=https://github.com/Kitware/CMake/releases/download/v$CMAKE_VERSION/cmake-$CMAKE_VERSION-linux-$(uname -m).tar.gz && \
    wget -O - -q "$url" | tar -C /usr/local --strip-components=1 -xzvf -

# Download the latest stable version of clang from apt.llvm.org.
ARG LLVM_VERSION=16
RUN apt update && \
    apt install -y --no-install-recommends \
        gnupg \
        lsb-release \
        software-properties-common \
        && \
    wget -O - -q https://apt.llvm.org/llvm.sh | bash -s -- $LLVM_VERSION && \
    rm -fr /var/lib/apt/lists/* && \
    ln -fsv /usr/lib/llvm-$LLVM_VERSION/bin/* /usr/local/bin

# Buster has Python 3.7, tc-build requires at least Python 3.8 due to liberal
# use of the walrus operator (':='), so build and install the latest stable
# version.
ARG PYTHON_VERSION=3.11.2
RUN dir=$(mktemp -d) && \
    url=https://www.python.org/ftp/python/$PYTHON_VERSION/Python-$PYTHON_VERSION.tar.xz && \
    wget -O - -q "$url" | tar -C "$dir" --strip-components=1 -xJvf - && \
    . /etc/os-release && \
    echo "deb-src http://deb.debian.org/debian $VERSION_CODENAME main" >/etc/apt/sources.list.d/deb-src-$VERSION_CODENAME.list && \
    apt update && \
    apt build-dep -y python3 && \
    apt install -y --no-install-recommends \
        libbz2-dev \
        libreadline-dev \
        libssl-dev \
        pkg-config \
        uuid-dev \
        zlib1g-dev \
        && \
    rm -fr /var/lib/apt/lists/* && \
    ( cd "$dir" && \
    ./configure --enable-optimizations ) && \
    make -C "$dir" -j"$(nproc)" && \
    make -C "$dir" -j"$(nproc)" install && \
    rm -fr "$dir"

# Install more binutils, kernel, and LLVM build dependencies
RUN apt update && \
    apt install -y --no-install-recommends \
        bc \
        binutils-dev \
        bison \
        build-essential \
        curl \
        file \
        flex \
        git \
        libelf-dev \
        make \
        ninja-build \
        texinfo \
        u-boot-tools \
        xz-utils \
        && \
    rm -fr /var/lib/apt/lists/*

# Build and install newer versions of GNU binutils to avoid issues with
# building the kernel.
RUN git clone -b rewrite-personal https://github.com/nathanchance/tc-build /tc-build && \
    /tc-build/build-binutils.py \
        --install-folder /usr/local \
        --targets \
            arm \
            powerpc \
            powerpc64 \
            powerpc64le \
            riscv64 \
            s390x \
        && \
    rm -fr /tc-build
