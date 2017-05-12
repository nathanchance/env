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

# Add Android SDK build tools to path
export PATH=${PATH}:/opt/android-sdk/build-tools/25.0.3

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
    if [[ $( command -v pacaur ) ]]; then
        pacaur -Syyu
    else
        sudo pacman -Syyu
    fi
}

# Flash build function
function flash_build {
    case ${1} in
        "arm64")
            export CROSS_COMPILE=/home/nathan/Toolchains/Prebuilts/gcc-6.x/bin/aarch64-linux-gnu-
            export ARCH=arm64
            export SUBARCH=arm64 ;;
    esac

    make clean
    make mrproper
    make flash_defconfig
    make -j$( nproc --all )
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
    deactivate && rm -rf ${HOME}/venv
}

# Repo sync shorthand
function rps {
    local ARGS

    if [[ -n ${1} ]]; then
        case ${1} in
            "k")
                ARGS="kernel/huawei/angler" ;;
            "g")
                ARGS="vendor/google/build "
                ARGS+="vendor/opengapps/sources/all "
                ARGS+="vendor/opengapps/sources/arm "
                ARGS+="vendor/opengapps/sources/arm64" ;;
            "v")
                ARGS="vendor/flash" ;;
            *)
                ARGS=${1} ;;
        esac
    fi

    repo sync -j$( nproc --all ) --force-sync -c --no-clone-bundle --no-tags --optimized-fetch --prune ${ARGS}
}

function ris-sparse {
    repo init -u ${1} -b ${2} --no-clone-bundle --depth=1

    time repo sync -j$( nproc --all ) --force-sync -c --no-clone-bundle --no-tags --optimized-fetch --prune
}

function ris {
    repo init -u ${1} -b ${2}

    time repo sync -j$( nproc --all ) --force-sync -c --no-clone-bundle --no-tags --optimized-fetch --prune
}

function gerrit-push {
    local ROM=${1}
    local PROJECT=${2}

    local URL
    local USER=nathanchance

    case ${1} in
        "du")
            URL=gerrit.dirtyunicorns.com
            BRANCH=n7x ;;
        "du-caf")
            URL=gerrit.dirtyunicorns.com
            BRANCH=n7x-caf ;;
        "omni")
            URL=gerrit.omnirom.org
            BRANCH=android-7.1 ;;
        "subs")
            URL=substratum.review
            if [[ ${PROJECT} = "substratum/interfacer" ]]; then
                BRANCH=n-rootless
            else
                BRANCH=n-mr2
            fi ;;
    esac

    if [[ -z ${PROJECT} ]]; then
        PROJECT=$(grep "projectname" .git/config | sed 's/\tprojectname = //')
    fi

    if [[ -n ${PROJECT} ]]; then
        echo "Executing git push ssh://${USER}@${URL}:29418/${PROJECT} HEAD:refs/for/${BRANCH}"
        git push ssh://${USER}@${URL}:29418/${PROJECT} HEAD:refs/for/${BRANCH}
    else
        echo "wtf happened?"
    fi
}
