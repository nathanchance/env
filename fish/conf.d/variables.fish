#!/usr/bin/env fish
# SPDX-License-Identifier: MIT
# Copyright (C) 2021-2023 Nathan Chancellor

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
            case nathan@aadp
                set -Ux LOCATION aadp
            case nathan@ax162
                set -Ux LOCATION hetzner
            case nathan@honeycomb
                set -Ux LOCATION honeycomb
            case nathan@raspberrypi pi@raspberrypi
                set -Ux LOCATION pi
            case nathan@hp-amd-ryzen-4300G
                set -Ux LOCATION test-desktop-amd-4300G
            case nathan@beelink-amd-ryzen-8745HS
                set -Ux LOCATION test-desktop-amd-8745HS
            case nathan@asus-intel-core-11700
                set -Ux LOCATION test-desktop-intel-11700
            case nathan@beelink-intel-n100
                set -Ux LOCATION test-desktop-intel-n100
            case nathan@asus-intel-core-4210U
                set -Ux LOCATION test-laptop-intel
            case nathan@thelio-3990X
                set -Ux LOCATION workstation
            case nathan@hyperv nathan@qemu nathan@vmware
                set -Ux LOCATION vm
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
    case generic
        set -gx CCACHE_MAXSIZE 25G
    case hetzner
        set -gx CCACHE_MAXSIZE 200G
    case test-desktop-amd-4300G test-laptop-intel pi vm
        set -gx CCACHE_MAXSIZE 15G
    case test-desktop-amd-8745HS test-desktop-intel-11700
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

if test -d /mnt/mac
    set -gx MAC_FOLDER /mnt/mac
end
set -gx OPT_ORB_GUEST /opt/orbstack-guest

if test -d "$MAC_FOLDER"/Volumes/Storage
    set -gx NAS_FOLDER "$MAC_FOLDER"/Volumes/Storage
else
    set -gx NAS_FOLDER /mnt/nas
end

set -gx NVME_FOLDER /mnt/nvme
set -gx NVME_SRC_FOLDER /mnt/nvme/src
if test -d $NVME_FOLDER
    set -gx EXT_FOLDER $NVME_FOLDER
else
    set -gx EXT_FOLDER $MAIN_FOLDER
end
set -gx MAIL_FOLDER $EXT_FOLDER/mail
set -gx TMP_FOLDER $EXT_FOLDER/tmp
set -gx VM_FOLDER $EXT_FOLDER/vm
set -gx XDG_FOLDER $EXT_FOLDER/xdg

set -gx CCACHE_DIR $XDG_FOLDER/config/ccache
set -gx PY_VENV_DIR $XDG_FOLDER/share/py_venv

set -gx CBL_GIT $CBL/github
set -gx CBL_LOGS $CBL/logs
set -gx CBL_MISC $CBL/misc
set -gx CBL_QEMU $CBL/qemu

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

set -gx CBL_SRC_C $CBL_SRC/clean
set -gx CBL_SRC_D $CBL_SRC/dev
set -gx CBL_SRC_M $CBL_SRC/mirrors
set -gx CBL_SRC_P $CBL_SRC/patched
set -gx CBL_SRC_W $CBL_SRC/worktrees

set -gx CBL_LKT $CBL_SRC_D/llvm-kernel-testing
set -gx CBL_TC_BLD $CBL_SRC_P/tc-build

set -gx CBL_QEMU_BIN $CBL_QEMU/bin
set -gx CBL_QEMU_INSTALL $CBL_QEMU/install
set -gx CBL_QEMU_SRC $CBL_QEMU/src

set -gx CBL_TC_BNTL_STORE $CBL_TC/binutils
set -gx CBL_TC_GCC_STORE $CBL_TC/gcc
set -gx CBL_TC_LLVM_STORE $CBL_TC/llvm

set -gx CBL_TC_BNTL $CBL_TC_BNTL_STORE-latest/bin
set -gx CBL_TC_LLVM $CBL_TC_LLVM_STORE-latest/bin

set -gx ENV_FOLDER $GITHUB_FOLDER/env
set -gx FORKS_FOLDER $GITHUB_FOLDER/forks

set -gx PYTHON_FOLDER $ENV_FOLDER/python
set -gx PYTHON_LIB_FOLDER $PYTHON_FOLDER/lib
set -gx PYTHON_SCRIPTS_FOLDER $PYTHON_FOLDER/scripts
set -gx PYTHON_BIN_FOLDER $PYTHON_SCRIPTS_FOLDER/bin
set -gx PYTHON_SETUP_FOLDER $PYTHON_FOLDER/setup
# shorthand version for use in interactive sessions or vim
set -gx PY_L $PYTHON_LIB_FOLDER
set -gx PY_S $PYTHON_SCRIPTS_FOLDER
set -gx PY_ST $PYTHON_SETUP_FOLDER

set -gx TMP_BUILD_FOLDER $TMP_FOLDER/build

set -gx ICLOUD_DOCS_FOLDER /Users/$USER/Library/'Mobile Documents/com~apple~CloudDocs/'

############################
## OTHER GLOBAL VARIABLES ##
############################

# bat paging arguments to avoid the default behavior of passing '-F' to 'less',
# which can be undesirable in certain contexts
set -gx BAT_PAGER_OPTS \
    --paging always \
    --pager 'less -R'

# Versions of stable that I build locally
set -gx CBL_STABLE_VERSIONS \
    6.13 \
    6.12 \
    6.6 \
    6.1 \
    5.15

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
set -gx FORGIT_LOG_GRAPH_ENABLE false

# My GitHub Container Registry URL
set -gx GHCR ghcr.io/nathanchance

# Hydro prompt custom function
set -g hydro_multiline true
set -g hydro_prompt_addons nathan
set -g hydro_cmd_duration_threshold 5000

# For building .deb packages on distros other than Debian/Ubuntu
set -gx KMAKE_DEB_ARGS \
    DPKG_FLAGS=-d \
    KDEB_CHANGELOG_DIST=unstable

# Hetzner IP address, slightly obsfucated
begin
    set -l parts 49 21 210 65
    set -gx HETZNER_IP (string join . $parts[-1] $parts[2] $parts[-2] $parts[1])
end

# Default to system session instead of user session for libvirt
set -gx LIBVIRT_DEFAULT_URI qemu:///system

# Always use blackbg for menuconfig
set -gx MENUCONFIG_COLOR blackbg

# Primary locations from list above
set -gx PRIMARY_LOCATIONS hetzner workstation

# My primary remote IP address
set -gx MAIN_REMOTE_IP $HETZNER_IP

# Current toolchain versions
set -gx GCC_VERSION_TOT 15
set -gx GCC_VERSION_STABLE 14
set -gx GCC_VERSION_MIN_KERNEL 5
set -gx GCC_VERSIONS_KERNEL (seq $GCC_VERSION_STABLE -1 $GCC_VERSION_MIN_KERNEL)
set -gx LLVM_VERSION_TOT 21
set -gx LLVM_VERSION_STABLE (math $LLVM_VERSION_TOT - 1)
set -gx LLVM_VERSION_MIN_KERNEL 11
set -gx LLVM_VERSIONS_KERNEL (seq $LLVM_VERSION_TOT -1 $LLVM_VERSION_MIN_KERNEL)
set -gx LLVM_VERSIONS_KERNEL_STABLE $LLVM_VERSIONS_KERNEL[2..]

# Stock GCC arguments for make
set -gx STOCK_GCC_VARS \
    CROSS_COMPILE=/usr/bin/ \
    K{A,C}FLAGS=-B/usr/bin

# https://www.kernel.org/category/releases.html
set -gx SUPPORTED_STABLE_VERSIONS \
    $CBL_STABLE_VERSIONS \
    5.10 \
    5.4

# Ensure that tmux temporary directory persists across reboots so that we can pass it through via systemd-nspawn
set -gx TMUX_TMPDIR /var/tmp

# Point tmuxp to configurations in env folder
set -gx TMUXP_CONFIGDIR $ENV_FOLDER/configs/tmux

# Allow an unlimited number of PIDs for tuxmake containers
set -gx TUXMAKE_PODMAN_RUN --pids-limit=-1

# Move Rust folders into XDG_DATA_HOME
set -gx CARGO_HOME $HOME/.local/share/cargo
set -gx RUSTUP_HOME $HOME/.local/share/rustup
