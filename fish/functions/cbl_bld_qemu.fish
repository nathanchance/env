#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

function cbl_bld_qemu -d "Build QEMU for use with ClangBuiltLinux"
    for arg in $argv
        switch $arg
            case -u --update
                set update true
        end
    end

    set qemu_501 $CBL_QEMU_SRC/qemu-5.0.1
    if not test -d $qemu_501
        mkdir -p (dirname $qemu_501)
        crl https://download.qemu.org/qemu-5.0.1.tar.xz | tar -C (dirname $qemu_501) -xJf -
    end

    set qemu_ppc $CBL_STOW_QEMU/5.0.1/bin/qemu-system-ppc
    if not test -x $qemu_ppc
        if grep -q 'LDFLAGS_NOPIE="-no-pie"' $qemu_501/configure
            echo 'diff --git a/configure b/configure
index 23b5e93752..c74f0910f7 100755
--- a/configure
+++ b/configure
@@ -2116,7 +2116,6 @@ EOF
 # Check we support --no-pie first; we will need this for building ROMs.
 if compile_prog "-Werror -fno-pie" "-no-pie"; then
   CFLAGS_NOPIE="-fno-pie"
-  LDFLAGS_NOPIE="-no-pie"
 fi
 
 if test "$static" = "yes"; then
@@ -2132,7 +2131,6 @@ if test "$static" = "yes"; then
   fi
 elif test "$pie" = "no"; then
   QEMU_CFLAGS="$CFLAGS_NOPIE $QEMU_CFLAGS"
-  QEMU_LDFLAGS="$LDFLAGS_NOPIE $QEMU_LDFLAGS"
 elif compile_prog "-Werror -fPIE -DPIE" "-pie"; then
   QEMU_CFLAGS="-fPIE -DPIE $QEMU_CFLAGS"
   QEMU_LDFLAGS="-pie $QEMU_LDFLAGS"
@@ -7673,7 +7671,6 @@ if test "$sparse" = "yes" ; then
   echo "QEMU_CFLAGS  += -Wbitwise -Wno-transparent-union -Wno-old-initializer -Wno-non-pointer-null" >> $config_host_mak
 fi
 echo "QEMU_LDFLAGS=$QEMU_LDFLAGS" >> $config_host_mak
-echo "LDFLAGS_NOPIE=$LDFLAGS_NOPIE" >> $config_host_mak
 echo "LD_REL_FLAGS=$LD_REL_FLAGS" >> $config_host_mak
 echo "LD_I386_EMULATION=$ld_i386_emulation" >> $config_host_mak
 echo "LIBS+=$LIBS" >> $config_host_mak' | patch -d $qemu_501 -p1
        end

        set qemu_501_bld $qemu_501/build
        rm -rf $qemu_501_bld
        mkdir $qemu_501_bld
        pushd $qemu_501_bld; or return

        $qemu_501/configure \
            --prefix=(string replace '/bin/qemu-system-ppc' '' $qemu_ppc) \
            --target-list=ppc-softmmu; or return
        make -skj(nproc) install; or return
        popd
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
            git -C $qemu_src reset --hard
            git -C $qemu_src submodule foreach git reset --hard
            git -C $qemu_src pull --rebase
            git -C $qemu_src submodule update --recursive
        end

        set qemu_ver (git -C $qemu_src sh -s --format=%H)
    end

    if test -z "$PREFIX"
        set PREFIX $CBL_STOW_QEMU/(date +%F-%H-%M-%S)-$qemu_ver
    end

    if not test -x $PREFIX/bin/qemu-system-x86_64
        set qemu_bld $qemu_src/build
        rm -rf $qemu_bld
        mkdir -p $qemu_bld
        pushd $qemu_bld; or return

        $qemu_src/configure --prefix=$PREFIX; or return
        make -skj(nproc) install; or return
        popd
    end

    rm -rf $CBL_QEMU_BIN
    mkdir -p $CBL_QEMU_BIN
    ln -frsv $qemu_ppc $CBL_QEMU_BIN
    for arch in arm aarch64 i386 m68k mips mipsel ppc64 riscv64 s390x x86_64
        ln -frsv $PREFIX/bin/qemu-system-$arch $CBL_QEMU_BIN
    end
    ln -frsv $PREFIX/bin/qemu-img $CBL_QEMU_BIN

    stow -d $CBL_STOW -R -v (basename (dirname $CBL_QEMU_BIN))
end
