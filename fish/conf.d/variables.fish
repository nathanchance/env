#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2022 Nathan Chancellor

#########################
##  LOCATION VARIABLE  ##
#########################

# This is the only variable that should be universal,
# as it needs to exist in containers
if test -z "$LOCATION"
    if test (uname) = Darwin
        set -Ux LOCATION mac
    else
        switch "$(id -un)@$hostname"
            case nathan@archlinux-'*' nathan@debian-'*' nathan@ubuntu-'*'
                set -Ux LOCATION hetzner-server
            case nathan@honeycomb
                set -Ux LOCATION honeycomb
            case pi@raspberrypi
                set -Ux LOCATION pi
            case nathan@hp-amd-ryzen-4300G
                set -Ux LOCATION test-desktop-amd
            case nathan@asus-intel-core-11700
                set -Ux LOCATION test-desktop-intel
            case nathan@asus-intel-core-4210U
                set -Ux LOCATION test-laptop-intel
            case nathan@thelio-3990X
                set -Ux LOCATION workstation
            case nathan@hyperv nathan@qemu nathan@vmware
                set -Ux LOCATION vm
            case nathan@MSI nathan@Ryzen-5-4500U nathan@Ryzen-9-3900X
                set -Ux LOCATION wsl
            case '*'
                set -Ux LOCATION generic
        end
    end
end



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
else if set -q GITHUB_ACTIONS
    set -gx MAIN_FOLDER $GITHUB_WORKSPACE
    set -gx ENV_FOLDER $MAIN_FOLDER/env
end
if not set -q MAIN_FOLDER
    set -gx MAIN_FOLDER $HOME
end

set -gx BIN_FOLDER $MAIN_FOLDER/bin
set -gx BIN_SRC_FOLDER $BIN_FOLDER/src
set -gx CBL $MAIN_FOLDER/cbl
set -gx GITHUB_FOLDER $MAIN_FOLDER/github
set -gx KERNEL_FOLDER $MAIN_FOLDER/kernel
set -gx SRC_FOLDER $MAIN_FOLDER/src

set -gx NAS_FOLDER /mnt/nas

set -gx NVME_FOLDER /mnt/nvme
if test -d $NVME_FOLDER
    set -gx EXT_FOLDER $NVME_FOLDER
else
    set -gx EXT_FOLDER $MAIN_FOLDER
end
set -gx AUR_FOLDER $EXT_FOLDER/aur
set -gx CCACHE_DIR $EXT_FOLDER/ccache
set -gx MAIL_FOLDER $EXT_FOLDER/mail
set -gx TMP_FOLDER $EXT_FOLDER/tmp
set -gx VM_FOLDER $EXT_FOLDER/vm
set -gx XDG_FOLDER $EXT_FOLDER/xdg

set -gx CBL_BLD $CBL/build
set -gx CBL_CI_GH $CBL/ci-gh
set -gx CBL_GIT $CBL/github
set -gx CBL_LKT $CBL/llvm-kernel-testing
set -gx CBL_QEMU $CBL/qemu
set -gx CBL_REPRO $CBL/repro-scripts
set -gx CBL_TC_BLD $CBL/tc-build
set -gx CBL_TMP $CBL/tmp
set -gx CBL_WRKTR $CBL/worktrees

set -gx HOST_FOLDER /mnt/host

set -gx SHARED_FOLDER /mnt/shared
if test -d $SHARED_FOLDER
    set -l CBL_SHARED (string replace $MAIN_FOLDER $SHARED_FOLDER $CBL)
    set -gx CBL_SRC $CBL_SHARED/src
    set -gx CBL_TC $CBL_SHARED/toolchains
else
    set -gx CBL_SRC $CBL/src
    set -gx CBL_TC $CBL/toolchains
end

set -gx CBL_BLD_C $CBL_BLD/clean
set -gx CBL_BLD_P $CBL_BLD/patched

set -gx CBL_QEMU_BIN $CBL_QEMU/bin
set -gx CBL_QEMU_INSTALL $CBL_QEMU/install
set -gx CBL_QEMU_SRC $CBL_QEMU/src

set -gx CBL_TC_BIN $CBL_TC/bin
set -gx CBL_TC_STOW $CBL_TC/stow
set -gx CBL_TC_STOW_BNTL $CBL_TC_STOW/binutils
set -gx CBL_TC_BNTL $CBL_TC_STOW_BNTL-latest/bin
set -gx CBL_TC_STOW_GCC $CBL_TC_STOW/gcc
set -gx CBL_TC_STOW_LLVM $CBL_TC_STOW/llvm
set -gx CBL_TC_LLVM $CBL_TC_STOW_LLVM-latest/bin

set -gx ENV_FOLDER $GITHUB_FOLDER/env
set -gx FORKS_FOLDER $GITHUB_FOLDER/forks

set -gx PYTHON_FOLDER $ENV_FOLDER/python
set -gx COMMON_PYTHON_FOLDER $PYTHON_FOLDER/common
set -gx USER_PYTHON_FOLDER $PYTHON_FOLDER/user

set -gx TMP_BUILD_FOLDER $TMP_FOLDER/build

set -gx ICLOUD_DOCS_FOLDER $HOME/Library/'Mobile Documents/com~apple~CloudDocs/'


############################
## OTHER GLOBAL VARIABLES ##
############################

# Versions of stable that I build locally
set -gx CBL_STABLE_VERSIONS \
    6.1 \
    6.0 \
    5.15 \
    5.10 \
    5.4

# ccache compression level
set -gx CCACHE_COMPRESS true
set -gx CCACHE_COMPRESSLEVEL 5

# vim as editor
set -gx EDITOR vim

# Default fzf options
set -gx FZF_DEFAULT_OPTS \
    --layout=reverse \
    --no-mouse

# Default forgit fzf options
# Done with individual variables because FORGIT_FZF_DEFAULT_OPTS
# might already be defined due to shell start up order
begin
    set -l var
    set -l vars \
        FORGIT_ADD_FZF_OPTS \
        FORGIT_BRANCH_DELETE_FZF_OPTS \
        FORGIT_CHECKOUT_BRANCH_FZF_OPTS \
        FORGIT_CHECKOUT_COMMIT_FZF_OPTS \
        FORGIT_CHECKOUT_FILE_FZF_OPTS \
        FORGIT_CHECKOUT_TAG_FZF_OPTS \
        FORGIT_CLEAN_FZF_OPTS \
        FORGIT_DIFF_FZF_OPTS \
        FORGIT_FIXUP_FZF_OPTS \
        FORGIT_IGNORE_FZF_OPTS \
        FORGIT_LOG_FZF_OPTS \
        FORGIT_REBASE_FZF_OPTS \
        FORGIT_RESET_HEAD_FZF_OPTS \
        FORGIT_REVERT_COMMIT_OPTS \
        FORGIT_STASH_FZF_OPTS

    for var in $vars
        set -gx $var $FZF_DEFAULT_OPTS
    end
end

# My GitHub Container Registry URL
set -gx GHCR ghcr.io/nathanchance

# Hydro prompt custom function
set -g hydro_multiline true
set -g hydro_prompt_addons nathan

# For building .deb packages on distros other than Debian/Ubuntu
set -gx KMAKE_DEB_ARGS \
    DPKG_FLAGS=-d \
    KDEB_CHANGELOG_DIST=unstable

# Default to system session instead of user session for libvirt
set -gx LIBVIRT_DEFAULT_URI qemu:///system

# Always use blackbg for menuconfig
set -gx MENUCONFIG_COLOR blackbg

# Primary location from list above
set -gx PRIMARY_LOCATION workstation

# My server IP address
if test -f $HOME/.server_ip
    set -g SERVER_IP (cat $HOME/.server_ip)
end

# Current toolchain versions
set -g GCC_VERSION_TOT 13
set -g GCC_VERSION_STABLE 12
set -g GCC_VERSION_MIN_KERNEL 5
set -g GCC_VERSIONS_KERNEL (seq $GCC_VERSION_STABLE -1 $GCC_VERSION_MIN_KERNEL)
set -g LLVM_VERSION_TOT 16
set -g LLVM_VERSION_STABLE (math $LLVM_VERSION_TOT - 1)
set -g LLVM_VERSION_MIN_KERNEL 11
set -g LLVM_VERSIONS_KERNEL (seq $LLVM_VERSION_TOT -1 $LLVM_VERSION_MIN_KERNEL)

# Stock GCC arguments for make
set -gx STOCK_GCC_VARS \
    CROSS_COMPILE=/usr/bin/ \
    K{A,C}FLAGS=-B/usr/bin

# https://www.kernel.org/category/releases.html
set -gx SUPPORTED_STABLE_VERSIONS \
    $CBL_STABLE_VERSIONS \
    4.19 \
    4.14 \
    4.9

# Point tmuxp to configurations in env folder
set -gx TMUXP_CONFIGDIR $ENV_FOLDER/configs/tmux

# Allow an unlimited number of PIDs for tuxmake containers
set -gx TUXMAKE_PODMAN_RUN --pids-limit=-1
