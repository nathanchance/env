###########
# EXPORTS #
###########

# ccache setup
export USE_CCACHE=1
ccache -M 200G

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
alias gpf='git push origin --force'
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


#############
# FUNCTIONS #
#############

# Flash build function
function flash_build {
   case ${1} in
      "shamu")
         export CROSS_COMPILE=/home/nathan/Kernels/Toolchains/Linaro/out/linaro-arm-eabi-6.x/bin/arm-eabi-
         export ARCH=arm
         export SUBARCH=arm ;;
      "angler")
         export CROSS_COMPILE="/home/nathan/Kernels/Toolchains/Linaro/out/aarch64-linux-android-6.x-kernel/bin/aarch64-linux-android-"
         export ARCH=arm64
         export SUBARCH=arm64 ;;
   esac

   make clean
   make mrproper
   make flash_defconfig
   make -j8
}

# Update Linux mirror function
function update_linux {
   cd ${HOME}/Kernels/linux
   git fetch -p origin
   git push --mirror
}

# Updating Arch function
function update {
   sudo pacman -Syu && pacaur -Syu
}

# Add remote function for kernel repos
function kernel_remotes {
   git remote add aosp https://android.googlesource.com/kernel/msm/ && git fetch aosp
   git remote add caf https://source.codeaurora.org/quic/la/kernel/msm-3.10 && git fetch caf
   git remote add linux https://github.com/nathanchance/linux && git fetch linux
   git remote add android-linux https://github.com/nathanchance/android-linux-upstream && git fetch android-linux
}

# EXKM to RC converter
function exkm2rc {
   sed -e 's/^/   write /' ${1} > ${2}
}
