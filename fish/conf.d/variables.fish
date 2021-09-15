#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021 Nathan Chancellor

######################################
##  GLOBAL CONFIGURATION VARIABLES  ##
######################################

set -Ux EDITOR vim

if test -f $HOME/.server_ip
    set -U SERVER_IP (cat $HOME/.server_ip)
else
    set -e SERVER_IP
end

set -l user (id -un)
set -l host (uname -n)
switch $user@$host
    case nathan@asus
        set -U LOCATION laptop
    case nathan@hp-4300G
        set -U LOCATION desktop
    case pi@raspberrypi
        set -U LOCATION pi
    case nathan@archlinux-'*' nathan@debian-'*' nathan@ubuntu-'*'
        set -U LOCATION server
    case nathan@hyperv nathan@vmware
        set -U LOCATION vm
    case nathan@MSI nathan@Ryzen-5-4500U nathan@Ryzen-9-3900X
        set -U LOCATION wsl
    case '*'
        set -U LOCATION generic
end



##########################################
##  LOCATION SPECIFIC FOLDER VARIABLES  ##
##########################################

switch $LOCATION
    case desktop laptop vm
        set -Ux MAIN_FOLDER $HOME/Dev
    case pi
        if test -d /mnt/ssd
            set -Ux MAIN_FOLDER /mnt/ssd
        end
end



###############################
##  GLOBAL FOLDER VARIABLES  ##
###############################

if not set -q MAIN_FOLDER
    set -Ux MAIN_FOLDER $HOME
end
set -Ux CBL $MAIN_FOLDER/cbl
set -Ux GITHUB_FOLDER $MAIN_FOLDER/github
set -Ux KERNEL_FOLDER $MAIN_FOLDER/kernel
set -Ux SRC_FOLDER $MAIN_FOLDER/src
set -Ux TMP_FOLDER $MAIN_FOLDER/tmp
set -Ux TC_FOLDER $MAIN_FOLDER/toolchains
set -Ux USR_FOLDER $MAIN_FOLDER/usr

set -Ux CBL_BLD $CBL/build
set -Ux CBL_GIT $CBL/github
set -Ux CBL_MIRRORS $CBL/mirrors
set -Ux CBL_QEMU $CBL/qemu
set -Ux CBL_SRC $CBL/src
set -Ux CBL_TC_BLD $CBL/tc-build
set -Ux CBL_TMP $CBL/tmp
set -Ux CBL_USR $CBL/usr
set -Ux CBL_WRKTR $CBL/worktrees

set -Ux CBL_BLD_C $CBL_BLD/clean
set -Ux CBL_BLD_P $CBL_BLD/patched

set -Ux CBL_QEMU_SRC $CBL_QEMU/src

set -Ux CBL_BIN $CBL_USR/bin
set -Ux CBL_STOW $CBL_USR/stow
set -Ux CBL_STOW_BNTL $CBL_STOW/binutils
set -Ux CBL_BNTL $CBL_STOW_BNTL-latest/bin
set -Ux CBL_STOW_LLVM $CBL_STOW/llvm
set -Ux CBL_LLVM $CBL_STOW_LLVM-latest/bin
set -Ux CBL_STOW_QEMU $CBL_STOW/qemu
set -Ux CBL_QEMU_BIN $CBL_STOW_QEMU-latest/bin

set -Ux ENV_FOLDER $GITHUB_FOLDER/env

set -Ux ANDROID_TC_FOLDER $TC_FOLDER/android
set -Ux GCC_TC_FOLDER $TC_FOLDER/gcc
set -Ux LLVM_TC_FOLDER $TC_FOLDER/llvm

set -Ux CBL_STABLE_VERSIONS 5.{1{4,3,0},4}
set -Ux CBL_LLVM_VERSIONS 10.0.1 11.1.0 12.0.1 13.0.0-rc3
# https://www.kernel.org/category/releases.html
set -Ux SUPPORTED_STABLE_VERSIONS 4.{{,1}4,{,1}9} 5.{4,1{0,3,4}}
