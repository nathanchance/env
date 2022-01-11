#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

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
if test -z "$LOCATION"
    switch $user@$hostname
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
end



##########################################
##  LOCATION SPECIFIC FOLDER VARIABLES  ##
##########################################

# MAIN_FOLDER value
switch $LOCATION
    case desktop laptop vm
        set -Ux MAIN_FOLDER $HOME/Dev
    case pi
        if test -d /mnt/ssd
            set -Ux MAIN_FOLDER /mnt/ssd
        end
end

# CCACHE_SIZE
switch $LOCATION
    case desktop laptop pi vm
        set -Ux CCACHE_MAXSIZE 15G
    case generic wsl
        set -Ux CCACHE_MAXSIZE 25G
    case server
        set -Ux CCACHE_MAXSIZE 150G
end



###############################
##  GLOBAL FOLDER VARIABLES  ##
###############################

if not set -q MAIN_FOLDER
    set -Ux MAIN_FOLDER $HOME
end
set -Ux AUR_FOLDER $MAIN_FOLDER/aur
set -Ux BIN_FOLDER $MAIN_FOLDER/bin
set -Ux BIN_SRC_FOLDER $BIN_FOLDER/src
set -Ux CBL $MAIN_FOLDER/cbl
set -Ux GITHUB_FOLDER $MAIN_FOLDER/github
set -Ux KERNEL_FOLDER $MAIN_FOLDER/kernel
set -Ux SRC_FOLDER $MAIN_FOLDER/src
set -Ux TMP_FOLDER $MAIN_FOLDER/tmp

set -Ux CBL_BLD $CBL/build
set -Ux CBL_GIT $CBL/github
set -Ux CBL_LKT $CBL/llvm-kernel-testing
set -Ux CBL_QEMU $CBL/qemu
set -Ux CBL_REPRO $CBL/repro-scripts
set -Ux CBL_SRC $CBL/src
set -Ux CBL_TC_BLD $CBL/tc-build
set -Ux CBL_TMP $CBL/tmp
set -Ux CBL_TC $CBL/toolchains
set -Ux CBL_WRKTR $CBL/worktrees

set -Ux CBL_BLD_C $CBL_BLD/clean
set -Ux CBL_BLD_P $CBL_BLD/patched

set -Ux CBL_QEMU_BIN $CBL_QEMU/bin
set -Ux CBL_QEMU_INSTALL $CBL_QEMU/install
set -Ux CBL_QEMU_SRC $CBL_QEMU/src

set -Ux CBL_TC_BIN $CBL_TC/bin
set -Ux CBL_TC_STOW $CBL_TC/stow
set -Ux CBL_TC_STOW_BNTL $CBL_TC_STOW/binutils
set -Ux CBL_TC_BNTL $CBL_TC_STOW_BNTL-latest/bin
set -Ux CBL_TC_STOW_LLVM $CBL_TC_STOW/llvm
set -Ux CBL_TC_LLVM $CBL_TC_STOW_LLVM-latest/bin

set -Ux ENV_FOLDER $GITHUB_FOLDER/env



#####################
## OTHER VARIABLES ##
#####################

set -Ux CBL_STABLE_VERSIONS 5.{1{6,5,0},4}
set -Ux CBL_LLVM_VERSIONS 10.0.1 11.1.0 12.0.1 13.0.0
# https://www.kernel.org/category/releases.html
set -Ux SUPPORTED_STABLE_VERSIONS 4.{{,1}4,{,1}9} 5.{4,1{0,5,6}}

# For building .deb packages on distros other than Debian/Ubuntu
set -Ux KMAKE_DEB_ARGS DPKG_FLAGS=-d KDEB_CHANGELOG_DIST=unstable

# GitHub Container Registry for myself
set -Ux GHCR ghcr.io/nathanchance
