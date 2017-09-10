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

# Try to attach via tmux
if [[ -z ${TMUX} ]] ;then
    ID=$( tmux ls | grep -vm1 attached | cut -d: -f1 ) # get the id of a deattached session
    if [[ -z ${ID} ]] ;then # if not available create a new one
        tmux -u new-session
    else
        tmux -u attach-session -t ${ID} # if available attach to it
    fi
fi

alias ls='ls --color=auto'

#PS1='[\u@\h \W]\$ '
#PS1='\[\033[01;34m\]\u@\h \[\033[01;32m\]\w\[\033[01;31m\] $(__git_ps1 "(%s) ")\[\033[39m\]\$\[\033[0m\] '

source ~/.git-prompt.sh
export GIT_PS1_SHOWDIRTYSTATE=1
export GIT_PS1_SHOWUPSTREAM=auto
export PROMPT_COMMAND='__git_ps1 "\[\033[01;34m\]\u@\h \[\033[01;32m\]\w\[\033[01;31m\]" " \[\033[39m\]\$\[\033[0m\] "'

###########
# EXPORTS #
###########

# ccache setup
ccache -M 150G &> /dev/null
export USE_CCACHE=1
export PATH="/usr/lib/ccache/bin/:${PATH}"

# Add Scripts directory and its subdirectories to $PATH
export PATH="${PATH}:${HOME}/Scripts"

# Log support so I can see what compiled and at what time
export LOGDIR=${HOME}/Web/me/Logs
# Create LOGDIR if it doesn't exist
if [[ ! -d ${LOGDIR} ]]; then
    mkdir -p ${LOGDIR}/Results
fi
export LOG=${LOGDIR}/Results/compile_log_$( TZ=MST date +%m_%d_%y ).log

# Export for building on Arch
export LC_ALL=C

# Add Android SDK build tools to path
export PATH=${PATH}:/opt/android-sdk/build-tools/25.0.3

# tmux alias
alias tmux='tmux -u'

# Update alias
alias update='pacaur -Syyu'

# Change directory aliases
alias 6p='cd ${HOME}/Kernels/angler'
alias asu='cd ${HOME}/Repos/ASU'
alias ayk='cd ${HOME}/Kernels/anykernel'
alias lnx='cd ${HOME}/Kernels/linux'
alias pkg='cd ${HOME}/Repos/PKGBUILDs'
alias op5='cd ${HOME}/Kernels/oneplus5'
alias tlc='cd ${HOME}/Toolchains'


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
alias gm='git merge'
alias gmc='git merge --continue'
alias gma='git merge --abort'

alias ga='git add'
alias gaa='git add -A'

alias gam='git am'

alias gc='git commit'
alias gcs='git commit --signoff'
alias gca='git commit --amend'
alias gcas='git commit --amend --signoff'
alias gac='git commit --all'
alias gacs='git commit --all --signoff'
alias gaca='git commit --all --amend'

alias grhe='git reset HEAD'
alias grh='git reset --hard'
alias grs='git reset --soft'

alias glg='git log'
alias glp="git log -p"
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
        PROJECT=$( grep "projectname" .git/config | sed 's/\tprojectname = //' )
    fi

    if [[ -n ${PROJECT} ]]; then
        PROJECT=$( echo ${PROJECT} | sed 's/DirtyUnicorns\///' )
        echo "Executing git push ssh://${USER}@${URL}:29418/${PROJECT} HEAD:refs/for/${BRANCH}"
        git push ssh://${USER}@${URL}:29418/${PROJECT} HEAD:refs/for/${BRANCH}
    else
        echo "wtf happened?"
    fi
}

#
# ex - archive extractor
# usage: ex <file>
#
function ex () {
	if [[ -f ${1} ]]; then
		case ${1} in
            *.tar.bz2)
                tar xjf ${1} ;;
            *.tar.gz)
                tar xzf ${1} ;;
            *.bz2)
                bunzip2 ${1} ;;
            *.rar)
                unrar x ${1} ;;
            *.gz)
                gunzip ${1} ;;
            *.tar)
                tar xf ${1} ;;
            *.tbz2)
                tar xjf ${1} ;;
            *.tgz)
                tar xzf ${1} ;;
            *.zip)
                unzip ${1} ;;
            *.Z)
                uncompress ${1} ;;
            *.7z)
                7z x ${1} ;;
            *)
                echo "'${1}' cannot be extracted via ex()" ;;
		esac
	else
		echo "'${1}' is not a valid file"
	fi
}

function upstable() {
    CUR_DIR=$(pwd)

    if [[ ! -d ${HOME}/Kernels/stable ]]; then
        cd ${HOME}/Kernels
        git clone --mirror https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git stable
        cd stable
        git remote set-url --push origin git@github.com:nathanchance/linux-stable
    fi

    cd ${HOME}/Kernels/stable

    git fetch -p origin
    git push --mirror

    cd ${CUR_DIR}
}
