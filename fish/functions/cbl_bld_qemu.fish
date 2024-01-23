#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_qemu -d "Build QEMU for use with ClangBuiltLinux"
    in_container_msg -c; or return

    for arg in $argv
        switch $arg
            case -u --update
                set update true
        end
    end

    if test -n "$VERSION"
        set qemu_src $CBL_QEMU_SRC/qemu-$VERSION
        mkdir -p (dirname $qemu_src)
        crl https://download.qemu.org/(basename $qemu_src).tar.xz | tar -C (dirname $qemu_src) -xJf -
        set qemu_ver $VERSION
    else
        set qemu_src $CBL_QEMU_SRC/qemu
        if not test -d $qemu_src
            mkdir -p (dirname $qemu_src)
            git clone -j(nproc) --recurse-submodules https://gitlab.com/qemu-project/qemu.git $qemu_src
        end

        git -C $qemu_src clean -dfqx
        git -C $qemu_src submodule foreach --recursive git clean -dfqx

        if test "$update" = true
            git -C $qemu_src remote update
            git -C $qemu_src reset --hard origin/master
            git -C $qemu_src submodule foreach git reset --hard
            git -C $qemu_src submodule update --recursive

            # Reverts
            for revert in $reverts
                git -C $qemu_src revert --no-edit $revert; or return
            end

            # Patches from mailing lists
            if set -q b4_patches
                pushd $qemu_src; or return
                for patch in $b4_patches
                    b4 am -l -o - -P _ $patch | git ap; or return
                end
                popd
            end
        end

        set qemu_ver (git -C $qemu_src sh -s --format=%H)
    end

    if test -z "$PREFIX"
        set PREFIX $CBL_QEMU_INSTALL/(date +%F-%H-%M-%S)-$qemu_ver
    end

    if not test -x $PREFIX/bin/qemu-system-x86_64
        set qemu_bld $qemu_src/build
        rm -rf $qemu_bld
        mkdir -p $qemu_bld
        pushd $qemu_bld; or return

        $qemu_src/configure \
            --disable-af-xdp \
            --disable-alsa \
            --disable-bochs \
            --disable-bpf \
            --disable-bzip2 \
            --disable-capstone \
            --disable-cloop \
            --disable-coreaudio \
            --disable-curl \
            --disable-dmg \
            --disable-docs \
            --disable-gcrypt \
            --disable-glusterfs \
            --disable-gnutls \
            --disable-gtk \
            --disable-keyring \
            --disable-l2tpv3 \
            --disable-libdaxctl \
            --disable-libiscsi \
            --disable-libnfs \
            --disable-libssh \
            --disable-libusb \
            --disable-linux-aio \
            --disable-lzo \
            --disable-nettle \
            --disable-opengl \
            --disable-oss \
            --disable-parallels \
            --disable-png \
            --disable-qed \
            --disable-qom-cast-debug \
            --disable-sdl \
            --disable-snappy \
            --disable-tpm \
            --disable-user \
            --disable-vde \
            --disable-vdi \
            --disable-vnc \
            --disable-vvfat \
            --disable-zstd \
            --disable-xen \
            --prefix=$PREFIX; or return
        make -skj(nproc) install; or return
        popd
    end

    cbl_upd_software_symlinks qemu $PREFIX
end
