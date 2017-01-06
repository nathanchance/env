#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
PS1='[\u@\h \W]\$ '

###########
# EXPORTS #
###########

# ccache setup
echo "ccache location: $(which ccache)"
ccache -M 200G
export USE_CCACHE=1

# Add Scripts directory and its subdirectories to $PATH
export PATH="${PATH}$(find ${HOME}/Scripts -name '.*' -prune -o -type d -printf ':%p')"

# Log support so I can see what compiled and at what time
export LOGDIR=${HOME}/Logs
# Create LOGDIR if it doesn't exist
if [[ ! -d ${LOGDIR} ]]; then
   mkdir -p ${LOGDIR}/Results
fi
export LOG=${LOGDIR}/Results/compile_log_$( TZ=MST date +%m_%d_%y ).log

# Export for building on Arch
export LC_ALL=C

# Build tools into PATH for Open GApps
export PATH=${PATH}:${HOME}/Misc/android-sdk-linux/build-tools/24.0.3

# Set ANDROID_HOME for Gradle
export ANDROID_HOME=${HOME}/Misc/android-sdk-linux

# Set NDK in path
export PATH=${PATH}:${HOME}/Misc/android-ndk-r13b-linux-x86_64

###############
# GIT ALIASES #
###############

alias gf='git fetch'
alias gcp='git cherry-pick'
alias gcpa='git cherry-pick --abort'
alias gcpc='git cherry-pick --continue'
alias gcpq='git cherry-pick --quit'

alias gph='git push'
alias gpo='git push origin'
alias gpf='git push --force'
alias gpsu='git push --set-upstream origin'

alias ga='git add'
alias gaa='git add -A'

alias gc='git commit'
alias gcs='git commit --signoff'
alias gca='git commit --amend'

alias grh='git reset --hard'

alias gl='git log --format=oneline'
alias gb='git branch -v'
alias gbd='git branch -D'

alias gs='git status'

alias grm='git remote'

alias gcb='git checkout -b'
alias gch='git checkout'

alias grb='git rebase'

alias gd='git diff'
alias gdc='git diff --cached'
alias gdh='git diff HEAD'

function gcpa {
   git cherry-pick ${1} && git commit --amend
}

#############
# FUNCTIONS #
#############

# Updating Arch function
function update {
   sudo pacman -Syu && pacaur -Syu

   if [[ "${1}" == "reboot" ]]; then
      sudo reboot
   fi
}

# Flash build function
function flash_build {
   case ${1} in
      "shamu")
         export CROSS_COMPILE=/home/nathan/Toolchains/Prebuilts/arm-eabi-6.x/bin/arm-eabi-
         export ARCH=arm
         export SUBARCH=arm ;;
      "angler"|"bullhead")
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
   virtualenv2 venv && source venv/bin/activate
}

function update_linaro {
   cd ${HOME}/Kernels/Toolchains/Linaro
   repo sync --force-sync -j$( grep -c ^processor /proc/cpuinfo )
   cd scripts

   case ${1} in
      "arm")
      bash arm-eabi-6.x ;;
      "arm64")
      bash aarch64-linux-android-6.x-kernel ;;
   esac

   cd ${HOME}
}
