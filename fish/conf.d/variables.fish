#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

######################################
##  GLOBAL CONFIGURATION VARIABLES  ##
######################################

set -gx EDITOR vim

if test -f $HOME/.server_ip
    set -g SERVER_IP (cat $HOME/.server_ip)
end

if test -z "$LOCATION"
    set -l user (id -un)
    switch $user@$hostname
        case nathan@archlinux-'*' nathan@debian-'*' nathan@ubuntu-'*'
            set -U LOCATION hetzner-server
        case pi@raspberrypi
            set -U LOCATION pi
        case nathan@hp-amd-ryzen-4300G
            set -U LOCATION test-desktop-amd
        case nathan@asus-intel-core-11700
            set -U LOCATION test-desktop-intel
        case nathan@asus-intel-core-4210U
            set -U LOCATION test-laptop-intel
        case nathan@thelio-3990X
            set -U LOCATION workstation
        case nathan@hyperv nathan@vmware
            set -U LOCATION vm
        case nathan@MSI nathan@Ryzen-5-4500U nathan@Ryzen-9-3900X
            set -U LOCATION wsl
        case '*'
            set -U LOCATION generic
    end
end

set -gx CCACHE_COMPRESS true
set -gx CCACHE_COMPRESSLEVEL 5


##########################################
##  LOCATION SPECIFIC FOLDER VARIABLES  ##
##########################################

# CCACHE_SIZE
switch $LOCATION
    case generic wsl
        set -gx CCACHE_MAXSIZE 25G
    case hetzner-server
        set -gx CCACHE_MAXSIZE 200G
    case test-desktop-amd test-laptop-intel pi vm
        set -gx CCACHE_MAXSIZE 15G
    case test-desktop-intel
        set -gx CCACHE_MAXSIZE 50G
    case workstation
        set -gx CCACHE_MAXSIZE 100G
end



###############################
##  GLOBAL FOLDER VARIABLES  ##
###############################

if test -d /mnt/ssd
    set -gx MAIN_FOLDER /mnt/ssd
    set -gx CCACHE_DIR $MAIN_FOLDER/ccache
else if test -d $HOME/Downloads
    set -gx MAIN_FOLDER $HOME/Dev
end
if not set -q MAIN_FOLDER
    set -gx MAIN_FOLDER $HOME
end

set -gx AUR_FOLDER $MAIN_FOLDER/aur
set -gx BIN_FOLDER $MAIN_FOLDER/bin
set -gx BIN_SRC_FOLDER $BIN_FOLDER/src
set -gx CBL $MAIN_FOLDER/cbl
set -gx GITHUB_FOLDER $MAIN_FOLDER/github
set -gx KERNEL_FOLDER $MAIN_FOLDER/kernel
set -gx SRC_FOLDER $MAIN_FOLDER/src
set -gx TMP_FOLDER $MAIN_FOLDER/tmp

set -gx CBL_BLD $CBL/build
set -gx CBL_GIT $CBL/github
set -gx CBL_LKT $CBL/llvm-kernel-testing
set -gx CBL_QEMU $CBL/qemu
set -gx CBL_REPRO $CBL/repro-scripts
set -gx CBL_SRC $CBL/src
set -gx CBL_TC_BLD $CBL/tc-build
set -gx CBL_TMP $CBL/tmp
set -gx CBL_TC $CBL/toolchains
set -gx CBL_WRKTR $CBL/worktrees

set -gx CBL_BLD_C $CBL_BLD/clean
set -gx CBL_BLD_P $CBL_BLD/patched

set -gx CBL_QEMU_BIN $CBL_QEMU/bin
set -gx CBL_QEMU_INSTALL $CBL_QEMU/install
set -gx CBL_QEMU_SRC $CBL_QEMU/src

set -gx CBL_TC_BIN $CBL_TC/bin
set -gx CBL_TC_STOW $CBL_TC/stow
set -gx CBL_TC_STOW_BNTL $CBL_TC_STOW/binutils
set -gx CBL_TC_BNTL $CBL_TC_STOW_BNTL-latest/bin
set -gx CBL_TC_STOW_LLVM $CBL_TC_STOW/llvm
set -gx CBL_TC_LLVM $CBL_TC_STOW_LLVM-latest/bin

set -gx ENV_FOLDER $GITHUB_FOLDER/env



#####################
## OTHER VARIABLES ##
#####################

set -gx CBL_STABLE_VERSIONS 5.{1{6,5,0},4}
set -gx CBL_LLVM_VERSIONS 10.0.1 11.1.0 12.0.1 13.0.0
# https://www.kernel.org/category/releases.html
set -gx SUPPORTED_STABLE_VERSIONS 4.{{,1}4,{,1}9} 5.{4,1{0,5,6}}

# For building .deb packages on distros other than Debian/Ubuntu
set -gx KMAKE_DEB_ARGS DPKG_FLAGS=-d KDEB_CHANGELOG_DIST=unstable

# GitHub Container Registry for myself
set -gx GHCR ghcr.io/nathanchance
