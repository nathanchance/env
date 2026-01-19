#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

function cbl_bld_qemu -d "Build QEMU for use with ClangBuiltLinux"
    __in_container_msg -c; or return

    for arg in $argv
        switch $arg
            case -i --install
                set install true
            case -u --update
                set update true
        end
    end

    if test -n "$VERSION"
        set qemu_src $CBL_QEMU_SRC/qemu-$VERSION
        mkdir -p (path dirname $qemu_src)
        crl https://download.qemu.org/(path basename $qemu_src).tar.xz | tar -C (path dirname $qemu_src) -xJf -

        set install_folder $VERSION
    else
        set qemu_src $CBL_QEMU_SRC/qemu
        if not test -d $qemu_src
            mkdir -p (path dirname $qemu_src)
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
            # https://lore.kernel.org/20250920234836.GA3857420@ax162/
            set -a b4_patches https://lore.kernel.org/qemu-devel/20250923143542.2391576-3-chenhuacai@kernel.org # hw/loongarch/virt: Align VIRT_GED_CPUHP_ADDR to 4 bytes
            if set -q b4_patches
                pushd $qemu_src; or return
                for patch in $b4_patches
                    b4 am -l -o - -P _ $patch | git ap; or return
                end
                popd
            end
        end

        set install_folder (cat $qemu_src/VERSION)-(date +%F-%H-%M-%S)-(git -C $qemu_src sh -s --format=%H)
    end

    if test -z "$PREFIX"
        set PREFIX $CBL_QEMU_INSTALL/$install_folder
    end

    if not test -x $PREFIX/bin/qemu-system-x86_64
        set qemu_bld (tbf $qemu_src)
        rm -rf $qemu_bld
        mkdir -p $qemu_bld
        pushd $qemu_bld; or return

        set configure_args \
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
            --disable-werror \
            --disable-zstd \
            --disable-xen

        if ld --help &| string match -qr discard-sframe
            set -a configure_args --extra-ldflags=-Wl,--discard-sframe
        end

        if test "$install" = true
            set -a configure_args --prefix=$PREFIX
            set make_target install
        end

        $qemu_src/configure $configure_args
        or return

        make -skj(nproc) $make_target
        or return

        popd
    end

    if test "$install" = true
        cbl_upd_software_symlinks qemu $PREFIX
    end
end
