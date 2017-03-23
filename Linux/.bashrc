#
# ~/.bashrc
#
# Copyright (C) 2017 Nathan Chancellor
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

###########
# EXPORTS #
###########

# ccache setup
ccache -M 500G &> /dev/null
export USE_CCACHE=1

# Add Scripts directory and its subdirectories to $PATH
export PATH="${PATH}$(find ${HOME}/Scripts -name '.*' -prune -o -type d -printf ':%p')"

# Log support so I can see what compiled and at what time
export LOGDIR=${HOME}/Web/Downloads/.superhidden/Logs
# Create LOGDIR if it doesn't exist
if [[ ! -d ${LOGDIR} ]]; then
    mkdir -p ${LOGDIR}/Results
fi
export LOG=${LOGDIR}/Results/compile_log_$( TZ=MST date +%m_%d_%y ).log

# Export for building on Arch
export LC_ALL=C

###############
# GIT ALIASES #
###############

# Alias hub to git
alias git='hub'

alias gf='git fetch'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpe='git cherry-pick --edit'
alias gcpc='git cherry-pick --continue'
alias gcpq='git cherry-pick --quit'

alias gph='git push'
alias gpo='git push origin'
alias gpf='git push --force'
alias gpsu='git push --set-upstream origin'

alias gpl='git pull'

alias ga='git add'
alias gaa='git add -A'

alias gam='git am'

alias gc='git commit'
alias gcs='git commit --signoff'
alias gca='git commit --amend'
alias gac='git commit --all'
alias gacs='git commit --all --signoff'
alias gaca='git commit --all --amend'

alias grhe='git reset HEAD'
alias grh='git reset --hard'
alias grs='git reset --soft'

alias glg='git log'
alias gl='git log --format=oneline'
alias gb='git branch -v'
alias gbd='git branch -D'

alias gs='git status'

alias grm='git remote'

alias gch='git checkout'
alias gcb='git checkout -b'

alias grb='git rebase'
alias grbi='git rebase -i'
alias grba='git rebase --abort'
alias grbc='git rebase --continue'

alias gd='git diff'
alias gdh='git diff HEAD'
alias gdhh='git diff HEAD^..HEAD'
alias gdss='git diff --shortstat'
alias gdc='git diff --cached'

#############
# FUNCTIONS #
#############

# Updating Arch function
function update {
    if [[ -n $( command -v pacaur ) ]]; then
        pacaur -Syyu
    else
        sudo pacman -Syyu
    fi

    if [[ "${1}" == "reboot" ]]; then
        sudo reboot
    fi
}

# Flash build function
function flash_build {
    case ${1} in
        "arm")
            export CROSS_COMPILE=/home/nathan/Toolchains/Prebuilts/arm-eabi-6.x/bin/arm-eabi-
            export ARCH=arm
            export SUBARCH=arm ;;
        "arm64")
            export CROSS_COMPILE=/home/nathan/Toolchains/Prebuilts/aarch64-linux-android-6.x/bin/aarch64-linux-android-
            export ARCH=arm64
            export SUBARCH=arm64 ;;
    esac

    make clean
    make mrproper
    make flash_defconfig
    make -j$( grep -c ^processor /proc/cpuinfo )
}

# Update Linux mirror function
function update_mirrors {
    CUR_DIR=$( pwd )

    cd ${HOME}/Kernels/linux-stable
    git fetch -p origin
    git push --mirror

    cd ${HOME}/Kernels/android-kernel-msm
    git fetch -p origin
    git push --mirror

    cd ${CUR_DIR}
}

# Add remote function for kernel repos
function kernel_remotes {
    git remote add aosp https://android.googlesource.com/kernel/msm/ && git fetch aosp
    git remote add caf https://source.codeaurora.org/quic/la/kernel/msm-3.10 && git fetch caf
    git remote add ls https://github.com/Flash-Kernel/linux-stable && git fetch ls
}

# EXKM to RC converter
function exkm2rc {
    sed -e 's/^/   write /' ${1} > ${2}
}

# Set up a virtual environment for Python
function mkavenv {
    virtualenv2 ${HOME}/venv && source ${HOME}/venv/bin/activate
}

# Deactivate and remove venv
function rmvenv {
    deactivate
    rm -rf ${HOME}/venv
}

# Repo sync shorthand
function rps {
    unset ARGS

    if [[ -n ${1} ]]; then
        case ${1} in
            "k")
                ARGS="kernel/huawei/angler" ;;
            "tc")
                ARGS="prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-6.x "
                ARGS+="prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-6.x "
                ARGS+="prebuilts/clang/host/linux-x86/3.9.1 "
                ARGS+="prebuilts/clang/host/linux-x86/4.0.0" ;;
            "gapps")
                ARGS="vendor/google/build "
                ARGS+="vendor/opengapps/sources/all "
                ARGS+="vendor/opengapps/sources/arm "
                ARGS+="vendor/opengapps/sources/arm64" ;;
            *)
                ARGS=${1} ;;
        esac
    fi

    repo sync --force-sync -j8 ${ARGS}

    unset ARGS
}
